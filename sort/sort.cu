#include<stdio.h>
#include<cuda_runtime.h>

#define length 256

__global__ void pr(int *a){
	int tid = threadIdx.x;
	__shared__ int a_s[length];
	a_s[tid] = a[tid];
	a[tid] = a_s[tid]*2;
}

int random(int range){
	static int star = 444;
	int d = 233333;
	int k = 33352;
	star = ((star*k)+d)%range;
	return star;
}

int* gen(){
	int *a_h;
	cudaHostAlloc( (void**)&a_h, length* sizeof(int),cudaHostAllocDefault );
	for (int i = 0; i < length; ++i)
	{
		a_h[i] = random(100);
		printf("a_h[%d] = %d \n",i,a_h[i]);
	}
	return a_h;
}

int main(){
	int *a_h = gen();
	int *a_d;
	cudaMalloc((void**) &a_d, sizeof(int) * length);
	cudaMemcpy(a_d, a_h, sizeof(int) * length,cudaMemcpyHostToDevice); 
	pr<<<1,length>>>(a_d);
	cudaMemcpy(a_h, a_d, sizeof(int) * length,cudaMemcpyDeviceToHost);
	for (int i = 0; i < length; ++i)
	{
		printf("a_h[%d] = %d \n",i,a_h[i]);
	}
}