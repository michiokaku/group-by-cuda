#include<stdio.h>
#include<cuda_runtime.h>
#include"order.h"

__global__ void cuda_order(int *a){
	int tid = threadIdx.x;
	
}

int order(int *a,int length){
	printf("order is running\n");
	int *dev_a;
	cudaMalloc((void**)&dev_a, length * sizeof(int)); 
	cudaMemcpy(dev_a, a, length * sizeof(int), cudaMemcpyHostToDevice);
	return 1;
}