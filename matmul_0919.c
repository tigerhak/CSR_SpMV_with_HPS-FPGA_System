#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/ipc.h>
#include <sys/shm.h>
#include <sys/mman.h>
#include <sys/time.h>
#include <math.h>
#include <time.h>
#include <stdint.h>

/*H2F Bus Base Offset*/
#define FPGA_AXI_BASE   0xC0000000
#define FPGA_AXI_SPAN   0x00001000

/*Onchip Base Offset*/
#define ONCHIP_OFFSET   0x08000000
#define ONCHIP_SPAN     0x00000fff
#define HPS_ONCHIP_BASE         0xffff0000
#define HPS_ONCHIP_SPAN         0x00010000

/*Define pointers*/
volatile unsigned int * onchip_ptr = NULL ;
volatile unsigned int * value_ptr = NULL ;
volatile unsigned int * format_ptr = NULL ;
volatile unsigned int * result_ptr = NULL ;

int fd;

int main (void)
{
        uint8_t i, j, k;
        uint8_t rows, cols, nnz;

        int test=0;
        double a,b,c,d;
        struct timespec begin0, end0;
    struct timespec begin1, end1;
    struct timespec begin2, end2;
    struct timespec begin3, end3;

        //printf("rows-cols-nnz : ");
        //scanf("%hhu-%hhu-%hhu", &rows, &cols, &nnz);
		
		 double value[6] = {1.03, 5.2, 7, 3.1, 10, 2};
		uint8_t row[6] = {1, 2, 6, 10, 11, 14};
		uint8_t col[6] = {0, 3, 7, 11, 13, 14};
		
		rows = 16;
		cols = 16; 
		nnz = 6;  


        uint8_t *row_idx = (uint8_t *)malloc(nnz * sizeof(uint8_t));
    uint8_t *col_idx = (uint8_t *)malloc(nnz * sizeof(uint8_t));
    __fp16 *values = (__fp16 *)malloc(nnz * sizeof(__fp16));
	
		for (i = 0; i < nnz; i++)
		{
			row_idx[i] = row[i];
			col_idx[i] = col[i];
			values[i] = (__fp16)value[i];
		}


        FILE *matrix;
        matrix = fopen("/home/linaro/data/matrix.txt", "w+");
        if (matrix==NULL){
                printf("[ERROR] can't open the matrix.txt\n");
                return(1);
        }

        for (i=0; i<nnz; i++){
                uint8_t row, col;
                __fp16 value;

                //row = i;
                //col = i;
                //value = 7.7 + i;
                fprintf(matrix, "%hhu %hhu %f\n", row_idx[i], col_idx[i], values[i]);

                //row_idx[i] = row;
                //col_idx[i] = col;
                //values[i] = value;
        }
        printf("[NOTICE] matrix.txt has been created or overwritten\n");


        if (nnz == 256){
                printf("[ERROR] matrix needs sparsity");
                return (1);
        }

        uint8_t row_ptr[rows + 1];

        for(i=0; i<rows; i++){
                row_ptr[i] = 0;
        }
        for(i=0; i<nnz; i++){
                row_ptr[row_idx[i]]++;
        }

        int sum=0;
        for (i=0; i<rows; i++){
                int temp = row_ptr[i];
                row_ptr[i] = sum;
                sum += temp;
        }
        row_ptr[rows] = nnz;

        __fp16 vector[rows];
        for (i=0; i<rows; i++){
                vector[i] = 1.0;
        }

        __fp16 SRAM0[rows+nnz];
        uint8_t SRAM1[nnz+rows+1];
        __fp16 result_sw[rows];

        clock_gettime(CLOCK_MONOTONIC, &begin0);
        memcpy(SRAM0, vector, sizeof(__fp16)*rows);
        memcpy(SRAM0+rows, values, sizeof(__fp16)*nnz);

        memcpy(SRAM1, col_idx, sizeof(uint8_t)*nnz);
        memcpy(SRAM1+nnz, row_ptr, sizeof(uint8_t)*(rows+1));
        clock_gettime(CLOCK_MONOTONIC, &end0);

        clock_gettime(CLOCK_MONOTONIC, &begin1);
        printf("\n[result (SW)]\n");
        for (i=0; i<rows; i++){
                result_sw[i] = 0.0;
                for (j=row_ptr[i]; j<row_ptr[i+1]; j++){
                        result_sw[i] += values[j] * vector[col_idx[j]];
                }
                printf("%f ", result_sw[i]);
        }
        clock_gettime(CLOCK_MONOTONIC, &end1);

        /*print sw output*/
        printf("\n[SRAM1 (SW)]\n");
        for(i=0; i<nnz+rows+1; i++){
                printf("%hhu ", SRAM1[i]);
        }
        printf("\n[SRAM0 (SW)]\n");
        for(i=0; i<rows+nnz; i++){
                printf("%f ", (float)SRAM0[i]);
        }
        printf("\n");

        /*get FPGA addresses*/
    if( ( fd = open( "/dev/mem", ( O_RDWR | O_SYNC ) ) ) == -1 )    {
        printf( "ERROR: could not open \"/dev/mem\"...\n" );
        return( 1 );
    }

    /*get virtual address for onchip sram*/
    /*AXI bus addr + Onchip offset*/
    onchip_ptr = mmap( NULL, ONCHIP_SPAN, ( PROT_READ | PROT_WRITE ), MAP_SHARED, fd, FPGA_AXI_BASE + ONCHIP_OFFSET);
    if( onchip_ptr == MAP_FAILED ) {
        printf( "ERROR: onchip_ptr mmap() failed...\n" );
        close( fd );
        return(1);
    }

    value_ptr = onchip_ptr + 120;
    format_ptr = onchip_ptr + 256;
    result_ptr = onchip_ptr + 384;

        clock_gettime(CLOCK_MONOTONIC, &begin2);
        memcpy((void*)value_ptr, SRAM0, sizeof(__fp16)*(rows+nnz));
        memcpy((void*)format_ptr, SRAM1, sizeof(uint8_t)*(nnz+rows+1));
        clock_gettime(CLOCK_MONOTONIC, &end2);

        printf("\npolling\n");
        clock_gettime(CLOCK_MONOTONIC, &begin3);
        *(onchip_ptr) = 1;
        while(*(onchip_ptr) != 0)
        {
                ;
        }
        clock_gettime(CLOCK_MONOTONIC, &end3);
        printf("\nHW end\n");

        printf("\n[result (HW)]\n");
        for(i=0; i<rows; i++){
                printf("%x ", *(result_ptr+i));
        }
        printf("\n[SRAM1 (HW)]\n");
        for (i = 0; i < (1 + rows + nnz) / 4 + 1; i++) {
    // 각 32비트 정수를 4개의 8비트 정수로 분리하여 출력
                uint32_t value = *(format_ptr + i);
                for (j = 0; j < 4; j++) {
                        uint8_t byte = (value >> (j * 8)) & 0xFF;
                        printf("%hhu ", byte);
                }
        }
        printf("\n[SRAM0 (HW)]\n");
        for (i = 0; i < (rows + nnz) / 2; i++) {
                // 32비트 정수를 부동 소수점 숫자로 변환하여 출력
                uint32_t int_value = *(value_ptr + i);
                __fp16 float_values[2];
                memcpy(float_values, &int_value, sizeof(__fp16) * 2);

                // 두 개의 부동 소수점 숫자를 출력
                printf("%f ", (float)float_values[0]);
                printf("%f ", (float)float_values[1]);
        }
        printf("\n");

        /* Compare Output */
        for(i=0; i<rows; i++){
        for(j=0; j<cols; j++){
            if(*(result_ptr + i*cols + j) != result_sw[i*cols+j]){
                test = 1;
            }
        }
        }
    printf("\n");

        if(test == 0){
        printf("TEST PASSED!");
    }
    else if(test == 1){
        printf("TEST FAILED!");
    }

    a = ((double)(end0.tv_sec - begin0.tv_sec)*1000000) + ((double)((end0.tv_nsec - begin0.tv_nsec) / 1000));
    b = ((double)(end1.tv_sec - begin1.tv_sec)*1000000) + ((double)((end1.tv_nsec - begin1.tv_nsec) / 1000));
    c = ((double)(end2.tv_sec - begin2.tv_sec)*1000000) + ((double)((end2.tv_nsec - begin2.tv_nsec) / 1000));
    d = ((double)(end3.tv_sec - begin3.tv_sec)*1000000) + ((double)((end3.tv_nsec - begin3.tv_nsec) / 1000));

    printf("\n SW matmul performance : %lf us, HW matmul performance : %lf us", b, d);
    printf("\n SW data transfer : %lf us, SW to HW data transfer %lf us", a, c);

    printf("\n");

        free(row_idx);
        free(col_idx);
        free(values);
        fclose(matrix);

        return 0;
}
