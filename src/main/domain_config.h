//
// Created by sachetto on 13/10/17.
//

#ifndef MONOALG3D_DOMAIN_CONFIG_H
#define MONOALG3D_DOMAIN_CONFIG_H

#include "../alg/grid/grid.h"
#include "config_common.h"

typedef struct domain_config domain_config_type;

typedef void (*set_spatial_domain_fn_pt)(struct grid *, struct domain_config *);

struct domain_config {
    struct config_common config_data;
    char *domain_name;
    double start_h, max_h, min_h;
    set_spatial_domain_fn_pt set_spatial_domain_fn;
};

void init_domain_functions(struct domain_config *config);
struct domain_config* new_domain_config();
void free_domain_config(struct domain_config* s);
void print_domain_config_values(struct domain_config* s);



#endif //MONOALG3D_STIM_CONFIG_H
