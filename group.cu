#include<stdio.h>

struct database{
    int table_lenth;//类别数量
    int num;    //成员数量
    char **table;//类别名称
    char ***data; //数据内容，以字符串存储
    int **data_lenth;//数据长度
};

struct group{
    int **index;//组中元素的索引
    int *lenth;//组的长度
};

void split_line(char **data_str,FILE *fp){
    char buf;
    char ed = -1;
    buf = fgetc(fp);
    while(buf != '\n' && buf != ed){
        int i = 0;
        while(buf != ',' && buf != '\n' && buf != ed){
            i++;
            printf("%c",buf);
            buf = fgetc(fp);
        }
        cudaHostAlloc( (void**)&da.table,da.table_lenth * sizeof(char*),cudaHostAllocDefault );
        printf("  i=%d ",i);
        if(buf == '\n')break;
        buf = fgetc(fp);
    }
}

database getdata(){
    database da;
    // da.table_lenth = 7 ;
    // da.num = 10;
    // cudaHostAlloc( (void**)&da.table,da.table_lenth * sizeof(char*),cudaHostAllocDefault );
    FILE *fp = fopen("./data/data.txt","r");
    if (fp == NULL)printf("file open fail !!!!\n");
    char buf;
    buf = fgetc(fp);
    printf("%c",buf);
    char ed = -1;
    da.table_lenth = 1;
    while(buf != '\n'){
        printf("%c",buf);
        if(buf == ',')da.table_lenth++;
        buf = fgetc(fp);
    }
    printf("table_lenth = %d \n",da.table_lenth);
    
    rewind(fp);
    split_line(da.table,fp);
    fclose(fp);
    return da;
}

int main(){
    char key_table[] = "math";//使用这个table来选择分组
    database da = getdata();//函数返回数据库
    // int *index = cuda_sort(da,key_table);//函数返回排序后的索引
    // int group = cuda_group_by(da,key_table);
}

