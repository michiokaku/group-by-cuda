#define ull unsigned long long int
#define MAX_THREAD 256

struct group{
    unsigned int * start;//组中元素的在数组中的起始位置
    unsigned int length;//组的数量
};

struct key_s{//只存储关键字
    unsigned char *point;//原字符串在组合后的字符串中的位置,用char以节约空间
    unsigned char point_length;//每个point的长度，根据具体数组长度确定
    ull point_num;//point的数量
    unsigned char *ppoint;//用来查找point的位置
    unsigned char ppoint_length;//每个ppoint的长度
    //long long int ppoint_num;//ppoint的数量,和point数量一样，省略掉
    char *key_str;//组合和字符串
    ull str_length;//字符串总长度
};

__device__ __host__ int find_group(group gp,int p);

__host__ __device__ void ltc(ull l,unsigned char *c,unsigned int p,unsigned char len);

__host__ __device__ void ctl(ull &l,unsigned char *c,unsigned int p,unsigned char len);

__host__ __device__ void itc(int in,unsigned char *c,unsigned int p,unsigned char len);

__host__ __device__ void cti(int &in,unsigned char *c,unsigned int p,unsigned char len);

__device__ int getppiont(key_s device,int tid);

group group_by_bitadd(group gp,bitadd ba,key_s &device);

void groupfree(group gp);

group group_init(int len);

void time_log();
