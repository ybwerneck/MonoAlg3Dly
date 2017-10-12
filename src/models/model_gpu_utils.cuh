/*! \brief Macros/inlines to assist CLion to parse Cuda files (*.cu, *.cuh) */
#ifdef __JETBRAINS_IDE__
#define __CUDACC__ 1
#define __host__
#define __device__
#define __global__
#define __forceinline__
#define __shared__
inline void __syncthreads() {}
inline void __threadfence_block() {}
template<class T> inline T __clz(const T val) { return val; }
struct __cuda_fake_struct { int x; int y; int z; };
extern __cuda_fake_struct blockDim;
extern __cuda_fake_struct threadIdx;
extern __cuda_fake_struct blockIdx;
#include "../../../../../opt/cuda/include/driver_types.h"
#include "../../../../../opt/cuda/include/cuda_runtime.h"
#endif

#include <stdlib.h>
#include <stdio.h>

void gpu_assert(cudaError_t code, const char *file, int line);

#define check_cuda_error(ans) { gpu_assert((ans), __FILE__, __LINE__); }
void gpu_assert(cudaError_t code, const char *file, int line)
{
    if (code != cudaSuccess)
    {
        fprintf(stderr,"GPU Error!: %s %s %d\n", cudaGetErrorString(code), file, line);
        exit(code);
    }
}