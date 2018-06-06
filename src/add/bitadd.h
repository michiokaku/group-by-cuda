#define MaxChildNum 6
#define MAX_THREADS_PER_BLOCK 512

struct bitadd{
    int length;
    unsigned char* c;
    unsigned short* s;
    unsigned int* i1;
    unsigned int* i2;
    unsigned int sum;
};

int range();

void bitprint(unsigned char c);

void gen(unsigned char *c,int len,int length);

void bitprint(unsigned char c);

__device__ __host__ unsigned short bts(unsigned char c);

__device__ int getba(bitadd ba,int index);

void bafree(bitadd &ba);

void bit_add(bitadd &ba);

unsigned int get_sum(bitadd &ba);
