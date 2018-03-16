#include<stdio.h>
#include<cuda_runtime.h>
#include"order.h"
#define length 256

int * gen(){
	int *a;
	cudaHostAlloc( (void**)&a, length* sizeof(int),cudaHostAllocDefault );
	for (int i = 0; i < length; ++i)
	{
		a[i] = -1;
	}
	return a ;
}

int main(){
	printf("main is running \n");
	int *a = gen();
	for (int i = 0; i < length; ++i)
	{
		printf("a[%d] = %d \n",i,a[i] );
	}
	order(a,length);
}