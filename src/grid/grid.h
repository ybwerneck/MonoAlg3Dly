//
// Created by sachetto on 29/09/17.
//

#ifndef MONOALG3D_GRID_H
#define MONOALG3D_GRID_H

#include "cell/cell.h"

#include <stdlib.h>
#include <stdio.h>

struct grid {

    struct cell_node *first_cell;     // First cell of grid.
    float side_length;        // Length of cube grid. Default = 1.0.
    uint64_t number_of_cells;  // Number of cells of grid.

    uint64_t original_num_cells;
    uint64_t num_active_cells;

    //TODO: @Incomplete
    /*
    vector <int> freeSVPositions;

    int *cellsToSolve;
    vector<int> refinedThisStep;

    vector<CellNode*> activeCells;
     */

    bool init_ode;
    bool parallel;
    bool gpu;
};


void initialize_grid(struct grid *the_grid, float side_length);
void construct_grid(struct grid *the_grid);
void initialize_and_construct_grid(struct grid *the_grid, float side_length);

void print_grid(struct grid* the_grid, FILE *output_file);
void free_grid(struct grid *the_grid);
void set_grid_flux(struct grid *the_grid);
bool refine_grid_with_bound(struct grid* the_grid, double min_h, double refinement_bound);
void refine_grid(struct grid* the_grid, int num_steps);
void refine_grid_cell_at(struct grid* the_grid, uint64_t cell_number );

bool derefine_grid_with_bound(struct grid *the_grid, double derefinement_bound, double max_h);
void derefine_all_grid (struct grid* the_grid);
void derefine_grid_inactive_cells (struct grid* the_grid);

void set_rabbit_mesh (struct grid *the_grid, const char *mesh_file);
void initialize_grid_with_mouse_mesh (struct grid *the_grid, const char *mesh_file);

#endif //MONOALG3D_GRID_H
