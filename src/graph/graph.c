#include "graph.h"

struct graph* new_graph ()
{
    struct graph *result = (struct graph*)malloc(sizeof(struct graph));
    result->last_node = NULL;
    result->list_nodes = NULL;
    result->total_nodes = 0;
    result->total_edges = 0;
    result->has_point_data = false;

    return result;
}

void free_list_edges (struct node *n)
{
    struct edge *e1 = n->list_edges;
    struct edge *e2 = n->list_edges->next;

    while (e1 != NULL)
    {
        e1->next = NULL;
        free(e1);
        e1 = e2;
        if (e2 != NULL)
            e2 = e2->next;
    }

    n->list_edges = NULL;
}

void free_list_nodes (struct graph *g)
{
    struct node *n1 = g->list_nodes;
    struct node *n2 = g->list_nodes->next;

    while (n1 != NULL)
    {
        if (n1->list_edges)
            free_list_edges(n1);
        
        n1->next = NULL;
        free(n1);
        n1 = n2;
        if (n2 != NULL)
            n2 = n2->next;
    }
}

void free_graph (struct graph *g)
{
    assert(g);

    if (g->list_nodes)
        free_list_nodes(g);
    
    free(g);
}

void insert_edge_graph (struct graph *g, const uint32_t id_1, const uint32_t id_2)
{
    
    struct node *n1, *n2;
	struct edge *edge;
	real_cpu norm;
	// Check if the edge is invalid
	if (id_1 == id_2) return;

	n1 = search_node(g,id_1);
	n2 = search_node(g,id_2);
	
    norm = calc_norm(n1->x,n1->y,n1->z,n2->x,n2->y,n2->z);
    edge = new_edge(id_2,norm,n2);
    // First edge
    if (!n1->list_edges)
        n1->list_edges = edge;
    // Iterate over the list and insert to the last edge
    else
    {
        struct edge *e = n1->list_edges;
        while (e->next != NULL)
            e = e->next;
        e->next = edge;
    }
    // Increment the number of edges of origin Node
    n1->num_edges++;
    // Increment the total number of edges from the graph
    g->total_edges++;
}

void insert_node_graph (struct graph *g, const real_cpu pos[], const real_cpu sigma)
{
    assert(g);

    struct node *tmp = g->list_nodes;
    struct node *node = new_node(g->total_nodes++,pos,sigma);
    // First node of the list
    if (!tmp)
    {
        g->list_nodes = node;
        g->last_node = node;
    }
    // Insert after the last node and update this pointer
    else
    {
        g->last_node->next = node;
        g->last_node = g->last_node->next;
    }
}

struct node* new_node (const uint32_t id, const real_cpu pos[], const real_cpu sigma)
{
    struct node *n = (struct node*)malloc(sizeof(struct node));
    n->id = id;
    n->x = pos[0];
    n->y = pos[1];
    n->z = pos[2];
    n->sigma = sigma;
    n->num_edges = 0;
    n->next = NULL;
    n->list_edges = NULL;
    
    return n;
}

struct edge* new_edge (const uint32_t id, const real_cpu size, struct node *dest)
{
    struct edge *e = (struct edge*)malloc(sizeof(struct edge));
	e->id = id;
	e->size = size;
	e->dest = dest;
	e->next = NULL;

	return e;
}

struct node* search_node (struct graph *g, const uint32_t id)
{
    struct node *tmp = g->list_nodes;
	while (tmp != NULL)
	{
		if (tmp->id == id)
			return tmp;
		tmp = tmp->next;
	}
    fprintf(stderr,"[-] ERROR! Node %d was not found!\n",id);
    
    return NULL;
}

void print_graph (struct graph *g)
{
    struct node *n = g->list_nodes;

    while (n != NULL)
    {
        struct edge *e = n->list_edges;
        fprintf(stdout,"|| %d (%.3lf,%.3lf,%.3lf) [%g] ||",n->id,n->x,n->y,n->z,n->sigma);

        while (e != NULL)
        {
            fprintf(stdout," --> || %d %.3lf (%.3lf,%.3lf,%.3lf) ||",e->id,e->size,e->dest->x,e->dest->y,e->dest->z);
            e = e->next;
        }
        fprintf(stdout,"\n");

        n = n->next;
    } 
    printf("Nodes = %u\n",g->total_nodes);
    printf("Edges = %u\n",g->total_edges);
    printf("Has point data = %d\n",g->has_point_data);


}

bool is_terminal (const struct node *n)
{
    if (n->num_edges == 1 && n->id != 0)
        return true;
    else
        return false;
}

real_cpu calc_norm (const real_cpu x1, const real_cpu y1, const real_cpu z1,\
                  const real_cpu x2, const real_cpu y2, const real_cpu z2)
{
    return sqrt(pow(x2-x1,2) + pow(y2-y1,2) + pow(z2-z1,2));
}