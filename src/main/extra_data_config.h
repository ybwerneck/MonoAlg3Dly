//
// Created by sachetto on 13/10/17.
//

#ifndef MONOALG3D_EXTRA_DATA_CONFIG_H
#define MONOALG3D_EXTRA_DATA_CONFIG_H

#include "../alg/grid/grid.h"
#include "../hash/string_hash.h"

typedef void * (*set_extra_data_fn_pt)(struct grid *, struct string_hash *);

struct extra_data_config {
    void *handle;
    char *extra_data_function;
    char *extra_data_library_file;
    struct string_hash *config;
    set_extra_data_fn_pt set_extra_data_fn;
    bool configured;
};

void init_extra_data_functions(struct extra_data_config *config);
struct extra_data_config* new_extra_data_config();
void print_extra_data_config_values(struct extra_data_config* s);
void free_extra_data_config(struct extra_data_config* s);

#endif //MONOALG3D_EXTRA_DATA_CONFIG_H
