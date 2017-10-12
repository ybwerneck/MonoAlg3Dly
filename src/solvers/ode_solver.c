//
// Created by sachetto on 02/10/17.
//

#include "ode_solver.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>
#include <assert.h>

#ifdef COMPILE_CUDA
#include <cuda_runtime.h>
#endif

struct ode_solver* new_ode_solver() {
    struct ode_solver* result = (struct ode_solver *) malloc(sizeof(struct ode_solver));
    result->sv = NULL;
    result->stim_currents = NULL;
    result->edo_extra_data = NULL;
    result->cells_to_solve = NULL;
    result->handle = NULL;
    result->gpu_id = 0;

    result->get_cell_model_data_fn = NULL;
    result->set_ode_initial_conditions_cpu_fn = NULL;
    result->solve_model_ode_cpu_fn = NULL;

    result->set_ode_initial_conditions_gpu_fn = NULL;
    result->solve_model_ode_gpu_fn = NULL;
    //result->update_gpu_fn = NULL;

    //init_ode_solver_with_cell_model(result);
    return result;
}

void free_ode_solver(struct ode_solver *solver) {
    if(solver->sv) {
        free(solver->sv);
    }

    if(solver->stim_currents) {
        free(solver->stim_currents);
    }

    if(solver->edo_extra_data) {
        free(solver->edo_extra_data);
    }

    if(solver->cells_to_solve) {
        free(solver->cells_to_solve);
    }

    if(solver->model_data.model_library_path) {
        free(solver->model_data.model_library_path);
    }

    if(solver->handle) {
        dlclose(solver->handle);
    }

    free(solver);

}


void init_ode_solver_with_cell_model(struct ode_solver* solver) {

    char *error;

    if(!solver->model_data.model_library_path) {
        fprintf(stderr, "model_library_path not provided. Exiting!\n");
        exit(1);
    }


    printf("Opening %s as model lib\n", solver->model_data.model_library_path);

    solver->handle = dlopen (solver->model_data.model_library_path, RTLD_LAZY);
    if (!solver->handle) {
        fputs (dlerror(), stderr);
        fprintf(stderr, "\n");
        exit(1);
    }

    solver->get_cell_model_data_fn = dlsym(solver->handle, "init_cell_model_data");
    if ((error = dlerror()) != NULL)  {
        fputs(error, stderr);
        fprintf(stderr, "init_cell_model_data function not found in the provided model library\n");
        if(!isfinite(solver->model_data.initial_v)) {
            fprintf(stderr, "intial_v not provided in the [cell_model] of the config file! Exiting\n");
            exit(1);
        }

    }

    solver->set_ode_initial_conditions_cpu_fn = dlsym(solver->handle, "set_model_initial_conditions_cpu");
    if ((error = dlerror()) != NULL)  {
        fputs(error, stderr);
        fprintf(stderr, "set_model_initial_conditions function not found in the provided model library\n");
        exit(1);
    }

    solver->solve_model_ode_cpu_fn = dlsym(solver->handle, "solve_model_ode_cpu");
    if ((error = dlerror()) != NULL)  {
        fputs(error, stderr);
        fprintf(stderr, "solve_model_ode_cpu function not found in the provided model library\n");
        exit(1);
    }

#ifdef COMPILE_CUDA
    solver->set_ode_initial_conditions_gpu_fn = dlsym(solver->handle, "set_model_initial_conditions_gpu");
    if ((error = dlerror()) != NULL)  {
        fputs(error, stderr);
        fprintf(stderr, "set_model_initial_conditions_gpu function not found in the provided model library\n");
        exit(1);
    }

    solver->solve_model_ode_gpu_fn = dlsym(solver->handle, "solve_model_ode_gpu");
    if ((error = dlerror()) != NULL)  {
        fputs(error, stderr);
        fprintf(stderr, "solve_model_ode_gpu function not found in the provided model library\n");
        exit(1);
    }


    /*solver->update_gpu_fn = dlsym(solver->handle, "update_gpu_after_refinement");
    if ((error = dlerror()) != NULL)  {
        fputs(error, stderr);
        fprintf(stderr, "update_gpu_after_refinement function not found in the provided model library\n");
        exit(1);
    }*/
#endif

}

void set_ode_initial_conditions_for_all_volumes(struct ode_solver *solver, uint32_t num_cells) {

    bool get_initial_v = !isfinite(solver->model_data.initial_v);
    bool get_neq = solver->model_data.number_of_ode_equations == -1;

    (*(solver->get_cell_model_data_fn))(&(solver->model_data), get_initial_v, get_neq);
    int n_odes = solver->model_data.number_of_ode_equations;

    if (solver->gpu) {
#ifdef COMPILE_CUDA

        set_ode_initial_conditions_gpu_fn_pt soicg_fn_pt = solver->set_ode_initial_conditions_gpu_fn;

        if(!soicg_fn_pt) {
            fprintf(stderr, "The ode solver was set to use the GPU, \n "
                    "but no function called set_model_initial_conditions_gpu "
                    "was provided in the %s shared library file\n", solver->model_data.model_library_path);
            exit(11);
        }

        if(solver->sv != NULL) {
            cudaFree(solver->sv);
        }

        solver->pitch = soicg_fn_pt(&(solver->sv), num_cells, n_odes);
#endif
    } else {

        set_ode_initial_conditions_cpu_fn_pt soicc_fn_pt = solver->set_ode_initial_conditions_cpu_fn;

        if(!soicc_fn_pt) {
            fprintf(stderr, "The ode solver was set to use the CPU, \n "
                    "but no function called set_model_initial_conditions_cpu "
                    "was provided in the %s shared library file\n", solver->model_data.model_library_path);
            exit(11);
        }

        if(solver->sv != NULL) {
            free(solver->sv);
        }

        solver->sv = (Real*)malloc(n_odes*num_cells*sizeof(Real));

        #pragma omp parallel for
        for(u_int32_t i = 0; i < num_cells; i++) {
            soicc_fn_pt(solver->sv + (i*n_odes));
        }
    }
}

void solve_all_volumes_odes(struct ode_solver *the_ode_solver, uint32_t n_active, Real cur_time, int num_steps) {

    assert(the_ode_solver->sv);

    uint32_t sv_id;

    Real dt = the_ode_solver->min_dt;
    int n_odes = the_ode_solver->model_data.number_of_ode_equations;
    Real *stims = the_ode_solver->stim_currents;
    Real *sv = the_ode_solver->sv;

    Real stim_start = the_ode_solver->stim_start;
    Real stim_dur = the_ode_solver->stim_duration;
    void *extra_data = the_ode_solver->edo_extra_data;

    Real time = cur_time;

    if(the_ode_solver->gpu) {
    #ifdef COMPILE_CUDA

        solve_model_ode_gpu_fn_pt solve_odes_pt = the_ode_solver->solve_model_ode_gpu_fn;
        solve_odes_pt(dt, sv, stims, the_ode_solver->cells_to_solve,
                n_active, stim_start, stim_dur, time, num_steps, n_odes, extra_data);

#endif
    }
    else {
        solve_model_ode_cpu_fn_pt solve_odes_pt = the_ode_solver->solve_model_ode_cpu_fn;
        #pragma omp parallel for private(sv_id, time)
        for (int i = 0; i < n_active; i++) {
            sv_id = the_ode_solver->cells_to_solve[i];

            for (int j = 0; j < num_steps; ++j) {
                solve_odes_pt(dt, sv + (sv_id * n_odes), stims[i], stim_start, stim_dur, cur_time, n_odes, extra_data);
                time += dt;
            }
        }
    }
}

//TODO: change this to the monodomain solver file
void update_state_vectors_after_refinement(struct ode_solver *ode_solver, uint32_vector *refined_this_step) {

    assert(ode_solver);
    assert(ode_solver->sv);

    size_t num_refined_cells = uint32_vector_size(refined_this_step)/8;

    Real *sv = ode_solver->sv;
    int neq = ode_solver->model_data.number_of_ode_equations;
    Real *sv_src;
    Real *sv_dst;

    if(ode_solver->gpu) {
    #ifdef COMPILE_CUDA

        size_t pitch_h = ode_solver->pitch;
        #pragma omp parallel for private(sv_src, sv_dst)
        for (size_t i = 0; i < num_refined_cells; i++) {

            size_t index_id = i * 8;

            uint32_t index = uint32_vector_at(refined_this_step, index_id);
            sv_src = &sv[index];

            for (int j = 1; j < 8; j++) {
                index = uint32_vector_at(refined_this_step, index_id + j);
                sv_dst = &sv[index];
                cudaMemcpy2D(sv_dst, pitch_h, sv_src, pitch_h, sizeof(Real), (size_t )neq, cudaMemcpyDeviceToDevice);
            }


        }
        //ode_solver->update_gpu_fn(sv, refined_this_step->base, num_refined_cells, neq);

    #endif
    }
    else {

        #pragma omp parallel for private(sv_src, sv_dst)
        for (size_t i = 0; i < num_refined_cells; i++) {

            size_t index_id = i * 8;

            uint32_t index = uint32_vector_at(refined_this_step, index_id);
            sv_src = &sv[index * neq];

            for (int j = 1; j < 8; j++) {
                index = uint32_vector_at(refined_this_step, index_id + j);
                sv_dst = &sv[index * neq];
                memcpy(sv_dst, sv_src, neq * sizeof(Real));
            }


        }
    }

}

int parse_ode_ini_file(void* user, const char* section, const char* name, const char* value)
{
    struct ode_solver* pconfig = (struct ode_solver*)user;
    pconfig->model_data.number_of_ode_equations = -1;
    pconfig->model_data.initial_v = INFINITY;

#define MATCH(s, n) strcmp(section, s) == 0 && strcmp(name, n) == 0
    if (MATCH("cell_model", "library_file_path")) {
        pconfig->model_data.model_library_path = strdup(value);
    } else if (MATCH("cell_model", "initial_v")) {
        pconfig->model_data.initial_v = (Real)atof(value);
    } else if (MATCH("cell_model", "num_equations_cell_model")) {
        pconfig->model_data.number_of_ode_equations = atoi(value);
    } else {
        return 0;  /* unknown section/name, error */
    }
    return 1;
}