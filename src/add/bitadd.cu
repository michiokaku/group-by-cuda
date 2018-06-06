#include<stdio.h>
#include<cuda_runtime.h>
#include"bitadd.h"
#include<math.h>

int tlog = 0;
cudaEvent_t start;
int n = 664;

int range(){
    n = n*5245 + 12345;
    n = n%32768;
    //printf("n = %d\n",n);
    float a = ((float)n)/32768.0;
    //printf("a = %f\n",a);
    int b = 0;
    if(a>0.5)b=1;
    return b;
}

void gen(unsigned char *c,int len,int length){
    for(int i=0;i<len;i++){
        c[i] = 0;
    }
    for(int i=0;i<length;i++){
        unsigned char cc = range();
        c[(i/8)] |= cc<<(i%8);
    }
    for(int i=0;i<len;i++){
        //printf("c[%d] = %d\n ",i,c[i]);
        //bitprint(c[i]);
    }
}

void bitprint(unsigned char c){
    int a =0;
    for(int i = 0;i<8;i++){
        a = (c>>i)&1;
        printf("%d",a);
    }
    printf("\n");
}

void time_log(){
    if(tlog == 0){
        cudaEventCreate(&start);
        cudaEventRecord(start,0);
    }
    else{
        float te;
        cudaEvent_t end;
        cudaEventCreate(&end);
        cudaEventRecord(end,0);
        cudaEventSynchronize(start);
        cudaEventSynchronize(end);
        cudaEventElapsedTime(&te,start,end);
        cudaEventRecord(start,0);
        printf("time = %f ms\n",te);
    } 
    tlog++;
}

__device__ __host__ unsigned short bts(unsigned char c){
    unsigned short a;
    a = c&1;
    a += (c>>1)&1;
    a += (c>>2)&1;
    a += (c>>3)&1;
    a += (c>>4)&1;
    a += (c>>5)&1;
    a += (c>>6)&1;
    a += (c>>7)&1;
    return a;
}

__device__ int getba(bitadd ba,int index){
    unsigned int a = 0;
    index --;
    if(index < 0)a +=0;
    else a += ba.s[index];

    index = index/(MAX_THREADS_PER_BLOCK*2);
    index--;
    if(index < 0)a += 0;
    else a += ba.i1[index];

    index = index/(MAX_THREADS_PER_BLOCK*2);
    if(index <= 0)a += 0;
    else a += ba.i2[index-1];

    return a;
}

__global__ void dev_get_back(unsigned int *a,bitadd ba){
    int tid = threadIdx.x+blockIdx.x*blockDim.x;
    if(tid<ba.length){
        a[tid] = getba(ba,tid);
    }
}

__global__ void bit_dev_add(unsigned char * c,unsigned short *sum,int length){
    int tid = threadIdx.x+blockIdx.x*blockDim.x;
    __shared__ unsigned short add_shared[MAX_THREADS_PER_BLOCK*2];

    unsigned char rc;
    int tid2 = tid*2;
    if(tid2<length)rc = c[tid2];
    else rc = 0;
    unsigned short ri = bts(rc);
    add_shared[threadIdx.x*2] = ri;
    tid2++;
    if(tid2<length)rc = c[tid2];
    else rc = 0;
    add_shared[(threadIdx.x*2)+1] = ri + bts(rc);
    __syncthreads();

    for(int i = 1;(MAX_THREADS_PER_BLOCK>>i)>0;i++){
        unsigned short ad = ((threadIdx.x<<1)&(0xFFFFFFFF<<(i+1)));
        unsigned short ad2 =0;
        ad |= threadIdx.x&(~(0xFFFFFFFF<<i));
        ad |= 1<<i;
        ad2 = ad&(~(1<<i));
        ad2 |= (~(0xFFFFFFFF<<i));
        add_shared[ad] += add_shared[ad2];
        __syncthreads();
    }
    sum[tid*2] = add_shared[threadIdx.x*2];
    sum[tid*2+1] = add_shared[threadIdx.x*2+1];
}

__global__ void short_dev_add(unsigned short * c,unsigned int *sum,int length){//length是sum的长度
    int tid = threadIdx.x+blockIdx.x*blockDim.x;
    __shared__ unsigned int add_shared[MAX_THREADS_PER_BLOCK*2];
    length++;

    int r1 = 0;
    int flag = tid*2 + 1;
    int index;
    if(flag<length){
        index = flag*MAX_THREADS_PER_BLOCK*2;
        index--;
        r1 = c[index];
        add_shared[threadIdx.x*2] = r1;
    }
    else add_shared[threadIdx.x*2] = 0;
    flag++;
    if(flag<length){
        index = flag*MAX_THREADS_PER_BLOCK*2;
        index--;
        r1 += c[index];
        add_shared[threadIdx.x*2+1] = r1;
    }
    else add_shared[threadIdx.x*2+1] = r1;
    
    __syncthreads();
    for(int i = 1;(MAX_THREADS_PER_BLOCK>>i)>0;i++){
        unsigned short ad = ((threadIdx.x<<1)&(0xFFFFFFFF<<(i+1)));
        unsigned short ad2 =0;
        ad |= threadIdx.x&(~(0xFFFFFFFF<<i));
        ad |= 1<<i;
        ad2 = ad&(~(1<<i));
        ad2 |= (~(0xFFFFFFFF<<i));
        add_shared[ad] += add_shared[ad2];
        __syncthreads();
    }
    flag = tid*2;
    sum[tid*2] = add_shared[threadIdx.x*2];
    flag++;
    sum[tid*2+1] = add_shared[threadIdx.x*2+1];
}

__global__ void int_dev_add(unsigned int * c,unsigned int *sum,int length){//到此为止只支持32位的地址寻找
    int tid = threadIdx.x+blockIdx.x*blockDim.x;
    __shared__ unsigned int add_shared[MAX_THREADS_PER_BLOCK*2];
    length++;

    int r1 = 0;
    int flag = tid*2 + 1;
    int index;
    if(flag<length){
        index = flag*MAX_THREADS_PER_BLOCK*2;
        index--;
        r1 = c[index];
        add_shared[threadIdx.x*2] = r1;
    }
    else add_shared[threadIdx.x*2] = 0;
    flag++;
    if(flag<length){
        index = flag*MAX_THREADS_PER_BLOCK*2;
        index--;
        r1 += c[index];
        add_shared[threadIdx.x*2+1] = r1;
    }
    else add_shared[threadIdx.x*2+1] = r1;
    
    __syncthreads();
    for(int i = 1;(MAX_THREADS_PER_BLOCK>>i)>0;i++){
        unsigned short ad = ((threadIdx.x<<1)&(0xFFFFFFFF<<(i+1)));
        unsigned short ad2 =0;
        ad |= threadIdx.x&(~(0xFFFFFFFF<<i));
        ad |= 1<<i;
        ad2 = ad&(~(1<<i));
        ad2 |= (~(0xFFFFFFFF<<i));
        add_shared[ad] += add_shared[ad2];
        __syncthreads();
    }
    flag = tid*2;
    sum[tid*2] = add_shared[threadIdx.x*2];
    flag++;
    sum[tid*2+1] = add_shared[threadIdx.x*2+1];
}

void bafree(bitadd &ba){
    cudaFree(ba.c);
    cudaFree(ba.s);
    cudaFree(ba.i1);
    cudaFree(ba.i2);
}

void iadd(bitadd &ba){
    printf("in the iadd\n");
    int length = ba.length;
    int block;
    for(int i=0;i<3;i++){
        block = length/(MAX_THREADS_PER_BLOCK*2);
        if((length%(MAX_THREADS_PER_BLOCK*2))>0)block++;
        if(i<2)length = block;
    }
    cudaMalloc((void**)&ba.i2,block*MAX_THREADS_PER_BLOCK*2*sizeof(unsigned int));
    cudaMemset(ba.i2,0,block*MAX_THREADS_PER_BLOCK*2*sizeof(unsigned int));
    int_dev_add<<<block,MAX_THREADS_PER_BLOCK>>>(ba.i1,ba.i2,length);
}

void sadd(bitadd &ba){
    int length = ba.length;
    int block;
    block = length/(MAX_THREADS_PER_BLOCK*2);
    if((length%(MAX_THREADS_PER_BLOCK*2))>0)block++;
    length = block;
    block = length/(MAX_THREADS_PER_BLOCK*2);
    if((length%(MAX_THREADS_PER_BLOCK*2))>0)block++;
    cudaMalloc((void**)&ba.i1,block*MAX_THREADS_PER_BLOCK*2*sizeof(unsigned int));
    cudaMemset(ba.i1,0,block*MAX_THREADS_PER_BLOCK*2*sizeof(unsigned int));
    short_dev_add<<<block,MAX_THREADS_PER_BLOCK>>>(ba.s,ba.i1,length);
    if(block>1)iadd(ba);
}

void bit_add(bitadd &ba){
    int block;
    int length = ba.length;
    block = length/(MAX_THREADS_PER_BLOCK*2);
    if((length%(MAX_THREADS_PER_BLOCK*2))>0)block++;
    cudaMalloc((void**)&ba.s,block*MAX_THREADS_PER_BLOCK*2*sizeof(unsigned short));
    bit_dev_add<<<block,MAX_THREADS_PER_BLOCK>>>(ba.c,ba.s,length);
    if(block>1)sadd(ba);
    ba.sum = get_sum(ba);
}

void bit_back(bitadd &ba,unsigned int *back){
    int block;
    int length = ba.length;
    block = length/(MAX_THREADS_PER_BLOCK);
    if((length%(MAX_THREADS_PER_BLOCK))>0)block++;

    dev_get_back<<<block,MAX_THREADS_PER_BLOCK>>>(back,ba);
}

unsigned int get_sum(bitadd &ba){
    int length = ba.length;
    int block;

    int t=0;
    for(int i=0;i<3;i++){
        block = length/(MAX_THREADS_PER_BLOCK*2);
        if((length%(MAX_THREADS_PER_BLOCK*2))>0)block++;
        if(i<2)length = block;
        t++;
        if(length<=1)break;
    }
    unsigned int sum = 0;
    int offset = MAX_THREADS_PER_BLOCK*2 -1;
    if(t == 1){
        cudaMemcpy(&sum,ba.s+offset,sizeof(unsigned short),cudaMemcpyDeviceToHost);
    }
    if(t == 2){
        cudaMemcpy(&sum,ba.i1+offset,sizeof(unsigned int),cudaMemcpyDeviceToHost);
    }
    if(t == 3){
        cudaMemcpy(&sum,ba.i2+offset,sizeof(unsigned int),cudaMemcpyDeviceToHost);
    }
    return sum;
}

void ck(int len,unsigned char *o,unsigned int *n){
    int sum = 0;
    int flag = 0;
    for(int i =0;i<len;i++){

        if(sum!=n[i]){
            flag = 1;
            printf("n[%d] = %d\n",i,n[i]);
            printf("o[%d] = %d\n",i,bts(o[i]));
            printf("sum = %d\n",sum);
            printf("has some error in %d \n",i);
        }
        sum+=bts(o[i]);
    }
    printf("check sum = %d\n",sum);
    if(flag == 0)printf("bit add worked succesed\n");
}

// int main(){
//     unsigned int length = 10;
//     float l = log(length)/log(2);
//     printf("log(length) = %f\n",l);
//     unsigned char *c;
//     int len = length/8;
//     if((length%8)>0)len++;
//     printf("len = %d\n",len);
//     cudaHostAlloc( (void**)&c,len * sizeof(unsigned char),cudaHostAllocDefault);
//     gen(c,len,length);
//     bitadd ba;
//     long long block = 1;
//     block = len/(MAX_THREADS_PER_BLOCK*2);
//     if((len%(MAX_THREADS_PER_BLOCK*2))>0)block++;
//     if(cudaSuccess != cudaMalloc((void**)&ba.c,len*sizeof(unsigned char))){
//         printf("cudamalloc error\n");
//     }

//     time_log();
//     cudaMemset(ba.c,0,len*sizeof(unsigned char));
//     time_log();

//     cudaMemcpy(ba.c,c,len*sizeof(unsigned char),cudaMemcpyHostToDevice);
//     ba.length = len;
//     time_log();
//     bit_add(ba);
//     printf("bit_add spend :   ");
//     time_log();

//     unsigned int *hb,*db;
//     cudaMalloc((void**)&db,(ba.length+1)*sizeof(unsigned int));
//     bit_back(ba,db);
//     cudaHostAlloc( (void**)&hb,(ba.length+1) * sizeof(unsigned int),cudaHostAllocDefault);
//     cudaMemcpy(hb,db,(ba.length+1)*sizeof(unsigned int),cudaMemcpyDeviceToHost);
//     ck(len,c,hb);
//     printf("sum = %d\n",ba.sum);
//     bafree(ba);
// }
