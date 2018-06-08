#include<stdio.h>
#include<string.h>
#include<cuda_runtime.h>
#include"../add/bitadd.h"
#include"../group_by/group_by.h"

#define block(length) (((length-1)/MAX_THREAD)+1)

void groupfree(group gp){
	cudaFree(gp.start);
}

group group_init(int len){
    group gp;
    gp.length = 1;
    cudaMalloc((void**)&gp.start,2*sizeof(int));
    int *start_h;
    cudaHostAlloc( (void**)&start_h,2 * sizeof(int),cudaHostAllocDefault);
    start_h[0] = 0;
    start_h[1] = len;
    cudaMemcpy(gp.start,start_h,2*sizeof(unsigned int),cudaMemcpyHostToDevice);
    cudaFreeHost(start_h);
    return gp;
}

__host__ __device__ void ltc(ull l,unsigned char *c,unsigned int p,unsigned char len){
    int a = p*len;
    for(int i=0;i<len;i++){
        c[i+a] = (l>>(8*i))&0xff;
    }
}

__host__ __device__ void ctl(ull &l,unsigned char *c,unsigned int p,unsigned char len){
    int a = p*len;
    l = 0;
    for(int i=0;i<len;i++){
        l += c[i+a]<<(8*i);
    }
}

__host__ __device__ void itc(int in,unsigned char *c,unsigned int p,unsigned char len){
    int a = p*len;
    for(int i=0;i<len;i++){
        c[i+a] = (in>>(8*i))&0xff;
    }
}

__host__ __device__ void cti(int &in,unsigned char *c,unsigned int p,unsigned char len){
    int a = p*len;
    in = 0;
    for(int i=0;i<len;i++){
        in += c[i+a]<<(8*i);
    }
}

__device__ int getppiont(key_s device,int tid){
	int a = device.ppoint_length*tid;
	int out = 0;
	for(int i=0;i<device.ppoint_length;i++){
		out += device.ppoint[i+a]<<(8*i);
	}
	return out;
}

__device__ int getpiont(key_s device,int tid){
    tid = getppiont(device,tid);
    int a = device.point_length*tid;

    int out = 0;
	for(int i=0;i<device.point_length;i++){
		out += device.point[i+a]<<(8*i);
	}

	return out;
}

__device__ int get_next_piont(key_s device,int tid){
	tid = getppiont(device,tid);
	int a = device.point_length*tid;
	a++;

	int out = 0;
	for(int i=0;i<device.point_length;i++){
		out += device.point[i+a]<<(8*i);
	}

	return out;
}

__device__ __host__ int find_group(group gp,int tid){
    int start,end;
    start = 0;
    end = gp.length;
    while((end - start)>1){
        int point = (start+end)/2;
        if(gp.start[point]<=tid)start=point;
        else end = point;
    }
    return start;
}

__device__ unsigned int get_position(bitadd ba,int tid){
    unsigned int position = getba(ba,tid/8);
    int t = tid%8;
    char c = ba.c[tid/8];
    for(int i=0;i<t;i++){
        position += (c>>i)&1;
    }
    return position;
}

__device__ unsigned int get_position_flag(bitadd ba,int tid,unsigned char &flag){
    unsigned int position = getba(ba,tid/8);
    int t = tid%8;
    char c = ba.c[tid/8];
    for(int i=0;i<t;i++){
        position += (c>>i)&1;
    }
    flag = (c>>t)&1;
    return position;
}

__global__ void point_change(group gp,bitadd ba,key_s device,unsigned char *new_pp){
    int tid = threadIdx.x+blockIdx.x*blockDim.x;
    if(tid<device.point_num){
        unsigned char flag;
        unsigned int position = get_position_flag(ba,tid,flag);
        int local_gp = find_group(gp,tid);
        int start = gp.start[local_gp];
        int next_start = gp.start[local_gp+1];
        unsigned int start_position = get_position(ba,start);
        unsigned int next_position = get_position(ba,next_start);
        int new_position;
        if(flag == 0){
            new_position = tid - position + start_position;
        }
        else{
            new_position = next_start - next_position + position;
        }
        int point;
        cti(point,device.ppoint,tid,device.ppoint_length);
        itc(point,new_pp,new_position,device.ppoint_length);
    }
    if(tid == (gridDim.x*blockDim.x-1)){
    	itc(device.point_num,new_pp,device.point_num,device.ppoint_length);
    }
}

__global__ void empty_check(group gp,bitadd ba,bitadd ba_group,key_s device){//找到下一轮为空的组，空为0，不空为1
    int tid = threadIdx.x+blockIdx.x*blockDim.x;
    __shared__ unsigned char add_shared[MAX_THREAD];//末尾两位存两组
    add_shared[threadIdx.x] = 0;
    __syncthreads();
    if(tid<gp.length){
        int len_gp;
        int start = gp.start[tid];
        len_gp = gp.start[tid+1] - start;
        unsigned char flag;
        int position = get_position_flag(ba,start+len_gp,flag)-get_position(ba,start);
        int add0 = 1,add1 = 1;
        if(position == len_gp)add0 = 0;
        if(position == 0)add1 = 0;
        add_shared[threadIdx.x] = add0|(add1<<1);
        __syncthreads();
        if(threadIdx.x<(MAX_THREAD/4)){
            unsigned char c;
            c = add_shared[(threadIdx.x*4)];
            c |= add_shared[(threadIdx.x*4+1)]<<2;
            c |= add_shared[(threadIdx.x*4+2)]<<4;
            c |= add_shared[(threadIdx.x*4+3)]<<6;

            tid = threadIdx.x + ((blockIdx.x*blockDim.x)/4);
            if(tid<ba.length){
                ba_group.c[tid] = c; 
            }   
        }
    }
}

//__global__ void put_new_group(group gp, group newgroup,bitadd ba,bitadd ba_group,key_s device){
//    int tid = threadIdx.x+blockIdx.x*blockDim.x;
//    if(tid < newgroup.length){
//    	unsigned char flag;
//        unsigned int position = get_position_flag(ba_group,tid,flag);
//        if(flag == 1){
//        	int start = gp.start[tid/2];//新的组初始的start的值和原来的组一样
//        	unsigned char branch = tid%2;//判断是新的组是原来组的左半边还是右半边，如果在右边则为一，左边为零
//
//        	if(branch == 1){
//        		int len_gp;
//        		if((tid/2) >= (gp.length-1)){
//        			len_gp = device.point_num-1-start;              //先获取之前组的长度
//        			len_gp -= ba.sum - get_position(ba,tid/2);    //ba.sum - get_position(ba,tid/2)得到原来组中为1项的数量
//        			                                              //再用len_gp减去它得到组中为零项的数量
//        		}
//        		else{
//        			len_gp = gp.start[(tid/2)+1] - start;
//        		    len_gp -= get_position(ba,tid/2+1) - get_position(ba,tid/2);
//        		}
//
//        		start += len_gp;
//        		newgroup.start[position] =  start;
//        	}
//        }
//    }
//}

__global__ void put_new_group(group gp, group newgroup,bitadd ba,bitadd ba_group,key_s device){
	int tid = threadIdx.x+blockIdx.x*blockDim.x;
	int half_griddim = gridDim.x/2;
	tid %= half_griddim*blockDim.x;//tid的值是对应的父节点的位置

	if((threadIdx.x == (blockDim.x-1))&&(blockIdx.x == (half_griddim-1))){//左半边最后一个线程给多出的一个组赋值
		newgroup.start[newgroup.length] = gp.start[gp.length];
	}

	if(tid<gp.length){
	//左半边的线程块用于创造左边的子树，右边同理
		unsigned char flag = 0;

		if(blockIdx.x<half_griddim){//左子树
			unsigned int position = get_position_flag(ba_group,tid*2,flag);
			if(flag == 1){//只有flag为1时才继续执行
				newgroup.start[position] = gp.start[tid];//左子树起点不变
			}
		}

		else{//右子树
			unsigned int position = get_position_flag(ba_group,tid*2+1,flag);
			if(flag == 1){
				newgroup.start[position] = gp.start[tid] + (gp.start[tid+1] - gp.start[tid])//父节点的长度
						- (get_position(ba,gp.start[tid+1]) - get_position(ba,gp.start[tid]));//父节点中为1的数量
			}
		}
	}
}

group new_group(group gp,bitadd ba,key_s device){
    bitadd ba_group;
    ba_group.length = ((gp.length-1)/4)+1;
    cudaMalloc((void**)&ba_group.c,ba_group.length*MAX_THREAD*sizeof(unsigned char));
    empty_check<<<block(ba_group.length),MAX_THREAD>>>(gp,ba,ba_group,device);
    bit_add(ba_group);
    group newgroup;
    newgroup.length = ba_group.sum;
    cudaMalloc((void**)&newgroup.start,(newgroup.length+1)*sizeof(int));//多分配一个方便计算长度。
    put_new_group<<<2*block(gp.length+1),MAX_THREAD>>>(gp,newgroup,ba,ba_group,device);
    bafree(ba_group);
    return newgroup;
}

__global__ void getchanged(key_s device,int *re){
	int tid = threadIdx.x+blockIdx.x*blockDim.x;
	if(tid<device.point_num){
		int r;
		cti(r,device.point,tid,device.point_length);
	}
}

void host_point_change(group gp,bitadd ba,key_s &device){
	unsigned char * new_pp;
	cudaMalloc((void**)&new_pp,device.ppoint_length*(device.point_num+1)*sizeof(unsigned char));
	point_change<<<block(device.point_num+1),MAX_THREAD>>>(gp,ba,device,new_pp);
	cudaFree(device.ppoint);
	device.ppoint = new_pp;
}

group group_by_bitadd(group gp,bitadd ba,key_s &device){
	host_point_change(gp,ba,device);
    group newgroup = new_group(gp,ba,device);
    bafree(ba);
    groupfree(gp);
    return newgroup;
}

//int main(){
//	time_log();
//	group gp = group_init();
//	int len = 1000;
//	unsigned char *c;
//	cudaHostAlloc( (void**)&c,len * sizeof(unsigned char),cudaHostAllocDefault);
//	for(int i=0;i<len;i++){
//		c[i] = i%256;
//	}
//	bitadd ba;
//	ba.length = len;
//	cudaMalloc((void**)&ba.c,len*sizeof(unsigned char));
//	cudaMemcpy(ba.c,c,len*sizeof(unsigned char),cudaMemcpyHostToDevice);
//	bit_add(ba);
//	key_s device;
//	device.point_num = 7999;
//	time_log();
//	group newgroup = group_by_bitadd(gp,ba,device);
//	int *a;
//	cudaHostAlloc( (void**)&a,newgroup.length * sizeof(int),cudaHostAllocDefault);
//	cudaMemcpy(a,newgroup.start,newgroup.length*sizeof(int),cudaMemcpyDeviceToHost);
//	for(int i =0;i<newgroup.length;i++){
//		printf("start[%d] = %d \n",i,a[i]);
//	}
//}

