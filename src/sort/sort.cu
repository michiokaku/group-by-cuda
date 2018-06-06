#include<stdio.h>
#include<cuda_runtime.h>
#include <stdlib.h>

#define length 10
#define length_thread 256

#define test(a){\
	for(int i =0;i<length;i++){\
		printf("a[%d] = %d \n",i,a[i] );\
	}\
}

#define pr_array(a,start,end){\
	for(int i=start;i<=end;i++){\
		printf("a[%d] = %d\n",i,a[i]);\
	}\
}

//return b_end where the vuela a will be put in the new array
//if a equel a vuale which is in the b array,a will in front of the vuale;
#define insert0(a,b,b_start,b_end){\
	while((b_end-b_start)>1){\
		int point = (b_start+b_end)/2;\
		 if(a<=b[point])b_end = point;\
		 else b_start = point;\
	}\
	b_end += (a>b[b_end])-(a<=b[b_start]);\
}\
//if a equel a vuale which is in the b array,a will in back of the vuale;
#define insert1(a,b,b_start,b_end){\
	while((b_end-b_start)>1){\
		int point = (b_start+b_end)/2;\
		 if(a<b[point])b_end = point;\
		 else b_start = point;\
	}\
	b_end += (a>=b[b_end])-(a<b[b_start]);\
}\


int cmp(const void *a,const void *b)
{
    return *(int *)a-*(int *)b;
}

__global__ void pr(int *a){
	int tid = threadIdx.x;
	__shared__ int a_s[length];
	a_s[tid] = a[tid];
	a[tid] = a_s[tid]*2;
}
					
__global__ void merger_thread(int *a,int len){
	__shared__ int a_s[length_thread];
	int tid = threadIdx.x + blockIdx.x * blockDim.x;
	int r1,r2;
	if(tid < len){
		a_s[threadIdx.x] = a[tid];
	}
	r1 = blockDim.x/2;
	int flag = (threadIdx.x>=r1);
	tid = threadIdx.x%r1;
	if((gridDim.x-1) == blockIdx.x)len %= blockDim.x;
	else len = blockDim.x;
	__syncthreads();
	if(threadIdx.x<(len/2)){
		r1 = threadIdx.x*2;
		if(a_s[r1]>a_s[r1+1]){
			r2 = a_s[r1];
			a_s[r1] = a_s[r1+1];
			a_s[r1+1] = r2;
		}
	}
	int loop = 1;
	int x , start , end;
	x = len;
	x = (x/2) + (x%2);
	while(x>1){
		x = (x/2) + (x%2);
		r1 = tid>>loop;
		r1 *= 2;
		start = r1+1-(int)flag;
		r1 += flag;
		end = 1<<loop;
		r1 *= end;
		start *= end;
		r2 = tid % end;
		r1 += r2;
		end += (start-1);
		__syncthreads();
		if(end > len)end = len;
		if(r1 < len){
			r1 = a_s[r1];
			if(flag){
				insert1(r1,a_s,start,end);
			}
			else{
				insert0(r1,a_s,start,end);
			}
			end %= (1<<loop);
			r2 +=end;
			a_s[r2] = r1;
		}
		loop++;
		__syncthreads();
	}
	if(threadIdx.x < len){
		a[threadIdx.x + blockIdx.x * blockDim.x] = a_s[threadIdx.x];
	}
}

int random(int range){
	static int start = 444;
	int d = 233333;
	int k = 33352;
	start = ((start*k)+d)%range;
	return start;
}

int* gen(){
	int *a_h;
	cudaHostAlloc( (void**)&a_h, length* sizeof(int),cudaHostAllocDefault );
	for (int i = 0; i < length; ++i)
	{
		a_h[i] = random(52);
		printf("a_h[%d] = %d \n",i,a_h[i]);
	}
	return a_h;
}

void sort_int(int *a,int len){
	int block_num = len/length_thread;
	if((len%length_thread)!=0)block_num++;
	merger_thread<<<block_num,length_thread>>>(a,len);
}

void msort(void *a,size_t num,size_t size,int ( * comparator ) ( const void *, const void * ) ){
	
}

int main(){
	/* int *a_h = gen();
	test(a_h);
	qsort(a_h,length,sizeof(int),cmp);
	printf("sorted!!!!!!!\n");
	test(a_h);
	a_h[43]=10;
	a_h[42]=10;
	pr_array(a_h,10,100);
	int start = 10,end = 50;
	insert0(10,a_h,start,end);
	printf("end %d\n",end );
	start = 10;
	end=50;
	insert1(10,a_h,start,end);
	printf("end %d\n",end );
	printf("used ipad pro maked\n");	 */
	int *a_h;
	cudaHostAlloc( (void**)&a_h, length* sizeof(int),cudaHostAllocDefault );
	for (int i = 0;i<length;i++) {
    	a_h[i] = length - i;
    	printf("a_h[%d] = %d \n",i,a_h[i]);
	}
	int *a_d;
	cudaMalloc( (void**)&a_d, length*sizeof(int) );
	cudaMemcpy(a_d,a_h, length*sizeof(int),cudaMemcpyHostToDevice);
	sort_int(a_d,length);
	cudaMemcpy(a_h,a_d,length*sizeof(int),cudaMemcpyDeviceToHost);
	for (int i = 0;i<length;i++) {
    	printf("a_h[%d] = %d \n",i,a_h[i]);
	}
}
