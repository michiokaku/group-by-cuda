#include<stdio.h>
#include<string.h>
#include<cuda_runtime.h>
#include"add/bitadd.h"
#include"group_by/group_by.h"

#define buflen 100
#define ull unsigned long long int
#define MAX_THREAD 256

void check_group_by_length(group gp,key_s device);
void check_len(unsigned char *len,key_s device);

struct line{
    char **data;//数据内容，以字符串存储
    int *data_lenth;//数据的字符串长度
};

struct database{
    int table_lenth;//类别数量
    ull num;    //成员数量
    line table;//类别名称
    line *ln;//成员的数据
};

int get_line_len(FILE *fp);

int get_block(int length){
    int block = length/MAX_THREAD;
    if((length%MAX_THREAD)!=0)block++;
    return block;
}

unsigned char get_pl(ull str_length){
    unsigned char pl;
    for(int i = 0;i<64;i++){
        if(((str_length>>i)&1)==1){
            pl = i;
        }
    }
    pl++;
    int a=0;
    if((pl%8)>0)a=1;
    pl = (pl/8) +a;
    return pl;
}

void strcopy(char *str1,char *str2){
    int i = 0;
    while(str2[i]&&(i<buflen)){
        str1[i] = str2[i];
        i++;
    }
}

int split_line(char **data_str,int *str_len,FILE *fp,int len){
    if(len != get_line_len(fp)){
        return 0;
    }
    len--;
    char *buf;
    buf = (char *)malloc(buflen*sizeof(char));
    for(int i = 0;i<len;i++){
        if(-1 == fscanf(fp,"%[^,],",buf))printf("wrong in 99");
        int a = strlen(buf);
        a++;
        str_len[i] = a;
        cudaHostAlloc( (void**)&data_str[i],a * sizeof(char),cudaHostAllocDefault);
        strcopy(data_str[i],buf);
        data_str[i][a-1]=0;
    }
    if(fscanf(fp,"%[^\n]\n",buf)==-1)printf("wrong in 107");
    int a = strlen(buf);
    a++;
    str_len[len] = a;
    cudaHostAlloc( (void**)&data_str[len],a * sizeof(char),cudaHostAllocDefault);
    strcopy(data_str[len],buf);
    data_str[len][a-1]=0;
    return 1;
}

int get_line_len(FILE *fp){      //获取数据库表头的元素的数量
    long a = ftell(fp); //记录开始位置，结束时要回去
    char buf = fgetc(fp);
    int len= 1;
    if(buf == ',')len++;
    while((buf != -1)&&(buf !='\n')){
        if(buf == ',')len++;
        buf = fgetc(fp);
    }
    fseek(fp,a,0);
    return len;
}

int get_len(FILE *fp){             //获取除了表头以外的行数
    char *buf;
    buf = (char *)malloc(1000*sizeof(char));
    long a = ftell(fp);
    if(fscanf(fp,"%s\n",buf)==-1)printf("wrong in 134");
    int len= -1;             //开始会算上表头，所以要从-1开始
    while(a!=ftell(fp)){
        a = ftell(fp);
        if(fscanf(fp,"%[^\n]\n",buf) == -1);//printf("wrong in 138");
        len++;
    }
    rewind(fp);
    free(buf);
    return len;
}

void goto_next_line(FILE *fp){
    char *buf;
    buf = (char *)malloc(1000*sizeof(char));
    int a = fscanf(fp,"%[^\n]\n",buf);
    if(a==-1)printf("goto_next_line has some problem\n");
    free(buf);
}

database getdata(const char *s){
    database da;
    FILE *fp = fopen(s,"r");
    if (fp == NULL){
        printf("open the \" %s \" failed !!!!\n",s);
        exit(1);
    }
    else printf("open the \" %s \" successful\n",s);
    fgetc(fp);
    da.table_lenth = get_line_len(fp);
    da.num = get_len(fp);  
    cudaHostAlloc( (void**)&da.table.data,da.table_lenth * sizeof(char*),cudaHostAllocDefault);
    cudaHostAlloc( (void**)&da.table.data_lenth,da.table_lenth * sizeof(int),cudaHostAllocDefault);
    if(0 == split_line(da.table.data,da.table.data_lenth,fp,da.table_lenth)){
        printf("The table has some proble!!!!\n");
        goto_next_line(fp);
    }

    cudaHostAlloc( (void**)&da.ln,da.num * sizeof(line),cudaHostAllocDefault);
    for(int i = 0;i<da.num;i++){
        cudaHostAlloc( (void**)&da.ln[i].data,da.table_lenth * sizeof(char*),cudaHostAllocDefault);
        cudaHostAlloc( (void**)&da.ln[i].data_lenth,da.table_lenth * sizeof(int),cudaHostAllocDefault);
        if(0 == split_line(da.ln[i].data,da.ln[i].data_lenth,fp,da.table_lenth)){
            printf("The number of field in line<%d>is not same with the table!!!!\n",i);
            goto_next_line(fp);
        }
    }
    fclose(fp);
    return da;
}

ull keylen(line *host,int len,int k){
    ull kl=0;
    for(int i=0;i<len;i++){
        kl+=(host[i].data_lenth[k]-1);
    }
    return kl;
}

int keyscp(line *host,key_s &khost,ull kl,int len,int k){
    int p = 0;
    khost.point_num = (len+1);//多给一个位置，用下一项的位置减当前项的位置来获取长度，最后一个没有下一项，需要多给一个
    khost.str_length = kl;
    khost.point_length = get_pl(kl);
    cudaHostAlloc( (void**)&khost.point,khost.point_num * khost.point_length * sizeof(char),cudaHostAllocDefault);
    khost.ppoint_length = get_pl(khost.point_num);
    cudaHostAlloc( (void**)&khost.ppoint,khost.point_num*khost.ppoint_length * sizeof(char),cudaHostAllocDefault);
    for(int i=0;i<len;i++){
        ltc(p,khost.point,i,khost.point_length);
        ltc(i,khost.ppoint,i,khost.ppoint_length);
        for(int j=0;j<(host[i].data_lenth[k]-1);j++){
            if(p>=kl)return 0;
            khost.key_str[p] = host[i].data[k][j];
            p++;
        }
    }
    ltc(kl,khost.point,len,khost.point_length);
    ltc(len,khost.ppoint,len,khost.ppoint_length);
    return 1;
}

void key_htd(line *host,key_s &device,int len,int k){
    ull kl = keylen(host,len,k);
    key_s khost;
    cudaHostAlloc( (void**)&khost.key_str,kl * sizeof(char),cudaHostAllocDefault);
    keyscp(host,khost,kl,len,k);
    device = khost;
    cudaMalloc( (void**)&device.point,device.point_num*device.point_length*sizeof(unsigned char));
    cudaMalloc( (void**)&device.ppoint,device.point_num*device.ppoint_length*sizeof(unsigned char));
    cudaMalloc( (void**)&device.key_str,device.str_length*sizeof(char));

    cudaMemcpy(device.point,khost.point, device.point_num*device.point_length*sizeof(unsigned char),cudaMemcpyHostToDevice);
    cudaMemcpy(device.ppoint,khost.ppoint, device.point_num*device.ppoint_length*sizeof(unsigned char),cudaMemcpyHostToDevice);
    cudaMemcpy(device.key_str,khost.key_str, device.str_length*sizeof(char),cudaMemcpyHostToDevice);

    cudaFreeHost(khost.point);
    cudaFreeHost(khost.ppoint);
    cudaFreeHost(khost.key_str);
}

void printline(line ln,int len){
    for(int i = 0;i<len;i++){
        printf("%s  ",ln.data[i]);
    }
    printf("\n");
}

void printdata(database da){
    printline(da.table,da.table_lenth);
    for(int i=0;i<da.num;i++){
        printline(da.ln[i],da.table_lenth);
    }
}

int getkey(database da,char *key_table){
    int k = -1;
    for(int i=0;i<da.table_lenth;i++){
        if(strcmp(da.table.data[i],key_table)==0){
            k = i;
            break;
        }
    }
    if(k == -1)printf("can not found the \" %s \"\n",key_table);
    else printf("found the key \" %s \", the index is %d\n",key_table,k);
    return k;
}

__global__ void dev_getlen(key_s device,unsigned char *len){
    int tid = threadIdx.x+blockIdx.x*blockDim.x;
    if(tid<(device.point_num)){
        int len1,len2;
        cti(len1,device.point,tid,device.point_length);
        cti(len2,device.point,(tid+1),device.point_length);
        len[tid] = len2 - len1;
    }
}

unsigned char * host_getlen(key_s device){
    unsigned char *len;
    cudaMalloc( (void**)&len,(device.point_num)*sizeof(unsigned char));
    int block = device.point_num/MAX_THREAD;
    if((device.point_num%MAX_THREAD)!=0)block++;
    dev_getlen<<<block,MAX_THREAD>>>(device,len);
    return len;
}

__global__ void gbl_bit(key_s device,unsigned char *len,int b,int length,bitadd ba){
    int tid = threadIdx.x+blockIdx.x*blockDim.x;
    __shared__ unsigned char add_shared[MAX_THREAD];
    add_shared[threadIdx.x] = 0;
    if(tid<length){
        add_shared[threadIdx.x] = (len[getppiont(device,tid)]>>b)&1;
        __syncthreads();
        unsigned char r;
        if(threadIdx.x <(MAX_THREAD/8)){
            r = add_shared[(threadIdx.x*8)];
            r |= add_shared[(threadIdx.x*8)+1]<<1;
            r |= add_shared[(threadIdx.x*8)+2]<<2;
            r |= add_shared[(threadIdx.x*8)+3]<<3;
            r |= add_shared[(threadIdx.x*8)+4]<<4;
            r |= add_shared[(threadIdx.x*8)+5]<<5;
            r |= add_shared[(threadIdx.x*8)+6]<<6;
            r |= add_shared[(threadIdx.x*8)+7]<<7;

            tid = threadIdx.x + ((blockIdx.x*blockDim.x)/8);
            if(tid<ba.length){
                ba.c[tid] = r; 
            }   
        }
    }
}

group group_by_length(unsigned char *len,key_s &device){//len是字符串的长度
    group gp = group_init(device.point_num);
    int length = device.point_num;
    for(int i=0;i<8;i++){   //char有八个比特，所以循环八次
        bitadd ba;
        ba.length = ((length-1)/8)+1;
        if((length%8)!=0)ba.length++;
        cudaMalloc( (void**)&ba.c,ba.length*sizeof(unsigned char));
        gbl_bit<<<get_block(length),MAX_THREAD>>>(device,len,7-i,length,ba);      //把第7-i位的值取出来放入ba.s中
        bit_add(ba);                       //使用bit_add函数计算出结果
        gp = group_by_bitadd(gp,ba,device);     //根据bit_add的结果分组
//        check_group_by_length(gp,device);
    }
    return gp;
}

group group_by(database da,char *key_table){
    int k = getkey(da,key_table);
    key_s device;
    key_htd(da.ln,device,da.num,k);
    device.point_num--;//长度多分配了一个，多出的一个给最后一个计算长度用，为了方便point_num不包括多分配的一个，所以--
    unsigned char *len = host_getlen(device);//首先先要获取每段字符串的长度，根据长度先分组
    check_len(len,device);
    group gp = group_by_length(len,device);//返回一个根据长度分组的结果
    check_group_by_length(gp,device);
    return gp;
}

void getpath(char * arg,char * c){
    int len = strlen(arg);
    len --;
    for(int i=0;i<=len;i++){
        if(arg[len-i] == '/'){
            arg[len-i+1] = 0;
            break;
        }
    }
    strcpy(c,arg);
    strcat(c,"../data/data.txt");
}

void key_s_dth(key_s device,key_s &host){
	host = device;
	cudaHostAlloc( (void**)&host.point,(host.point_length+1) * host.point_num * sizeof(unsigned char),cudaHostAllocDefault);
	cudaHostAlloc( (void**)&host.ppoint,(host.ppoint_length+1) * host.point_num * sizeof(unsigned char),cudaHostAllocDefault);
	cudaHostAlloc( (void**)&host.key_str,(host.str_length+1) * sizeof(unsigned char),cudaHostAllocDefault);

	cudaMemcpy(host.point,device.point, (host.point_num+1)*host.point_length*sizeof(unsigned char),cudaMemcpyDeviceToHost);
	cudaMemcpy(host.ppoint,device.ppoint, (host.point_num+1)*host.ppoint_length*sizeof(unsigned char),cudaMemcpyDeviceToHost);
	cudaMemcpy(host.key_str,device.key_str, (host.str_length+1)*sizeof(char),cudaMemcpyDeviceToHost);
}

int check_get_length(key_s h,int tid){
	int pp;
	cti(pp,h.ppoint,tid,h.ppoint_length);
	int p1,p2;
	cti(p1,h.point,pp,h.point_length);
	cti(p2,h.point,pp+1,h.point_length);
	int p = p2-p1;
	return p;
}

void check_len(unsigned char *len,key_s device){
	unsigned char *h_len;
	cudaHostAlloc( (void**)&h_len,device.point_num * sizeof(unsigned char),cudaHostAllocDefault);
	cudaMemcpy(h_len,len, device.point_num*sizeof(unsigned char),cudaMemcpyDeviceToHost);
	key_s host;
	key_s_dth(device,host);

	int flag = 0;
	for(int i=0;i<(host.point_num-1);i++){
		unsigned char clen = check_get_length(host,i);
		if(clen != h_len[i]){
			printf("h_len[%d] = %d\n",i,h_len[i]);
			flag = 1;
		}
	}
	if(flag == 0)printf("len is right\n");
}

void check_group_by_length(group gp,key_s device){
	unsigned char *h_len;
	key_s host;
	key_s_dth(device,host);
	cudaHostAlloc( (void**)&h_len,host.point_num * sizeof(unsigned char),cudaHostAllocDefault);

	int last = -1;
	for(int i=0;i<(host.point_num);i++){
		h_len[i] = check_get_length(host,i);
		if(last != h_len[i]){
			last = h_len[i];
			printf("h_len[%d] = %d\n",i,h_len[i]);
		}
	}
}

int main(int argc, char * argv[]){
    char key_table[] = "python";//使用这个table来选择分组
    char c[100];
    getpath(argv[0],c);//工作目录与执行文件的相对路径可以根据argv[0]得到
    database da = getdata(c);//函数返回数据库
    group gp;
    if(argc>1)gp = group_by(da,argv[1]);
    else gp = group_by(da,key_table);
    int *a;
    cudaHostAlloc( (void**)&a,gp.length * sizeof(int),cudaHostAllocDefault);
    cudaMemcpy(a,gp.start,gp.length*sizeof(int),cudaMemcpyDeviceToHost);
    for(int i=0;i<gp.length;i++){
    	printf("a[%d] = %d \n",i,a[i]);
    }
}

