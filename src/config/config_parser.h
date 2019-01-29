/*
 * opts.h
 *
 *  Created on: 27/05/2011
 *      Author: sachetto
 */

#ifndef MONOALG3D_CONFIG_PARSER_H
#define MONOALG3D_CONFIG_PARSER_H

#ifdef _MSC_VER
#include "../getopt/getopt.h"
#else
#include <getopt.h>
#endif

#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <math.h>
#include "../alg/grid/grid.h"

#include "domain_config.h"
#include "purkinje_config.h"
#include "extra_data_config.h"
#include "assembly_matrix_config.h"
#include "save_mesh_config.h"
#include "linear_system_solver_config.h"
#include "../hash/stim_config_hash.h"
#include "save_state_config.h"
#include "restore_state_config.h"

#define START_REFINING 1700
#define DOMAIN_OPT 1800
#define EXTRA_DATA_OPT 1900
#define STIM_OPT 2000
#define ASSEMBLY_MATRIX_OPT 2100
#define LINEAR_SYSTEM_SOLVER_OPT 2200
#define DRAW_OPT 3000
#define SAVE_OPT 3100
#define SAVE_STATE_OPT 3200
#define RESTORE_STATE_OPT 3300
#define BETA 4000
#define CM 5000

struct user_options {
    float final_time;				/*-f option */
    bool final_time_was_set;
    bool adaptive;	                /*-a option */
    bool adaptive_was_set;
    float ref_bound;				/*-r option*/
    bool ref_bound_was_set;
    float deref_bound;				/*-d option*/
    bool deref_bound_was_set;
    float dt_pde;					/*-z option*/
    bool dt_pde_was_set;
    float dt_ode;				    /*-e option*/
    bool dt_ode_was_set;
    int num_threads;                /*-n option*/
    bool num_threads_was_set;
    bool gpu;                       /*-g option*/
    bool gpu_was_set;
    int refine_each;                /*-R option*/
    bool refine_each_was_set;
    int derefine_each;              /*-D option*/
    bool derefine_each_was_set;
    int gpu_id;                     /*-G option*/
    bool gpu_id_was_set;
    bool abort_no_activity;         /*-b option*/
    bool abort_no_activity_was_set;
    float vm_threshold;            /*-v option*/
    bool vm_threshold_was_set;

    char *model_file_path;          /*-k option*/
    bool model_file_path_was_set;

    bool draw;

    float beta;
    bool beta_was_set;

    float cm;
    bool cm_was_set;

    float start_adapting_at;
    bool start_adapting_at_was_set;
    char *config_file;              /*-c option*/

    struct stim_config_hash *stim_configs;
    struct domain_config *domain_config;
    struct purkinje_config *purkinje_config;
    struct extra_data_config *extra_data_config;
    struct assembly_matrix_config *assembly_matrix_config;
    struct linear_system_solver_config *linear_system_solver_config;
    struct save_mesh_config *save_mesh_config;
    struct save_state_config *save_state_config;
    struct restore_state_config *restore_state_config;

    bool main_found;

};

struct batch_options {
    char *batch_config_file;     /*-c option*/
    char *output_folder;         //TODO: maybe we can create here a option for this
    char *initial_config;
    int num_simulations;
    int num_par_change;
    struct string_hash *config_to_change;
};

void display_usage( char** argv );
void display_batch_usage(char **argv);

struct user_options * new_user_options();
struct batch_options * new_batch_options();
void parse_options(int argc, char**argv, struct user_options *user_args);
void parse_batch_options(int argc, char**argv, struct batch_options *user_args);

void get_config_file(int argc, char**argv, struct user_options *user_args);
int parse_config_file(void* user, const char* section, const char* name, const char* value);
int parse_batch_config_file(void *user, const char *section, const char *name, const char *value);

void configure_grid_from_options(struct grid* grid, struct user_options *options);
void free_user_options(struct user_options *s);
void issue_overwrite_warning(const char *var, const char *section, const char *old_value, const char *new_value, const char *config_file);
#endif /* MONOALG3D_CONFIG_PARSER_H */