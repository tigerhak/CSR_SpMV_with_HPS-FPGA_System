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
#include <string.h>
#include <stdint.h>

//H2F BUS BASE OFFSET
#define FPGA_AXI_BASE   0xC0000000
#define FPGA_AXI_SPAN   0x00001000

//ONCHIP BASE OFFSET
#define ONCHIP_OFFSET   0x08000000
#define ONCHIP_SPAN     0x00000fff
#define HPS_ONCHIP_BASE         0xffff0000
#define HPS_ONCHIP_SPAN         0x00010000

volatile unsigned int * onchip_ptr = NULL ;
volatile unsigned int * in_vector_ptr = NULL ;
volatile unsigned int * mat_vector_ptr = NULL ;
volatile unsigned int * row_ptr_ptr = NULL ;
volatile unsigned int * col_idx_ptr = NULL ;
volatile unsigned int * result_ptr = NULL ;
volatile unsigned int * mat_a_ptr = NULL ;
volatile unsigned int * mat_b_ptr = NULL ;
volatile unsigned int * mat_c_ptr = NULL ;

int fd;

int main(void){
	
	int i,j,k;
	int test=0;
	double a,b,c,d;
	struct timespec begin0, end0;
    struct timespec begin1, end1;
    struct timespec begin2, end2;
    struct timespec begin3, end3;
	
	 // === get FPGA addresses ==================

    if( ( fd = open( "/dev/mem", ( O_RDWR | O_SYNC ) ) ) == -1 )    {
        printf( "[ERROR] could not open \"/dev/mem\"...\n" );
        return( 1 );
    }
	
	 // ===========================================
     // get virtual address for onchip sram
     // AXI bus addr + Onchip offset
    onchip_ptr = mmap( NULL, ONCHIP_SPAN, ( PROT_READ | PROT_WRITE ), MAP_SHARED, fd, FPGA_AXI_BASE + ONCHIP_OFFSET);

    if( onchip_ptr == MAP_FAILED ) {
        printf( "[ERROR] onchip_ptr mmap() failed...\n" );
        close( fd );
        return(1);
    }
		
	in_vector_ptr	=	onchip_ptr + 120;
	mat_vector_ptr	= 	onchip_ptr + 128;
	row_ptr_ptr		=	onchip_ptr + 256;
	col_idx_ptr		=	onchip_ptr + 264;
	result_ptr		=	onchip_ptr + 384;
	
	// Make Random COO matrix
	uint8_t num_nnz;
	printf("num_nnz? ");
	scanf("%hhu", &num_nnz);
	
	if(num_nnz >= 256 || num_nnz < 0){
		printf("[ERROR] num_nnz is 0~255");
		return (1);
	}
	
	uint8_t *coo_row = (uint8_t *)malloc(num_nnz * sizeof(uint8_t));
	uint8_t *coo_col = (uint8_t *)malloc(num_nnz * sizeof(uint8_t));
	__fp16 *value = (__fp16 *)malloc(num_nnz * sizeof(__fp16));
	
	srand(time(NULL));
	coo_row[0] = 0;
	coo_col[0] = 0;
	
	uint8_t isDuplicate(uint8_t *coo_row, uint8_t *coo_col, uint8_t row_idx, uint8_t col_idx, uint8_t current_idx)
	{
		for (i=0; i<current_idx; i++)
		{
			if (coo_row[i] = row_idx && coo_col[i] = col_idx) return (1);
		}
		return (0);
	}		
	
	int max_attempts = 10000; // max attempts to find pairs
	
	printf("\n* input initialization\n");
	clock_gettime(CLOCK_MONOTONIC, &begin0);
	for (i=1; i<num_nnz; i++)
	{
		int attempts = 0;
		do
		{
			coo_row[i] = coo_row[i-1] + (rand()%2);
			coo_col[i] = coo_col[i-1] + (rand()%2);
			if (coo_row[i] > 16) coo_row[i]=16;
			if (coo_col[i] > 16) coo_col[i]=16;
			attempts++;
		} while (isDuplicate(row, col, row[i], col[i], i) && attempts < max_attempts);
	
		if (attempts >= max_attempts)
		{
			printf("[ERROR] maximum attempts reached");
			free(coo_row);
			free(coo_col);
			free(value);
			return (1);
		}
		
		//value[i] = ((double)rand() / RAND_MAX) * 10.0;
		value[i] = 7.7 + i;
	}
	clock_gettime(CLOCK_MONOTONIC, &end0);
	
	
	// Print COO format matrix
	printf("[coo_row] ");
	for (i=0; i<num_nnz; i++){
		printf("%hhu ", coo_row[i]);
	}
	printf("\n");
	printf("[coo_col] ");
	for (i=0; i<num_nnz; i++){
		printf("%hhu ", coo_col[i]);
	}
	printf("\n");
	printf("[mat_vector] ");
	for (i=0; i<16; i++){
		printf("%f ", value[i]);
	}
	printf("\n");
	printf("\n* all in_vector value is 1\n");
	
	// Make input vector
	__fp16 in_vector[16] = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1};
	
	// SW Multiplication
	clock_gettime(CLOCK_MONOTONIC, &begin1);
    __fp16 result_sw[16];
        for(i=0; i<16; i++)
        {
                __fp16 sum = 0.0;
                for(j=0; j<num_nnz; j++)
                {
                        if(coo_row[j] == i)
                        {
                                sum += value[j] * in_vector[coo_col[j]];
                        }
                }
                result_sw[i] = sum;
        }
    clock_gettime(CLOCK_MONOTONIC, &end1);

    printf("* SW end\n");
	
	// COO to CSR encoding
	uint8_t row_ptr[17];

	// Initialize row_ptr to all 0
	for(i=0; i<17; i++){
		row_ptr[i] = 0;
	}

	// Count the number of non-zero elements in each row
	for(i=0; i<num_nnz; i++){
		row_ptr[coo_row[i] + 1]++;
	}

	// Cumulative sum to compute row_ptr
	for(i=1; i<17; i++){
		row_ptr[i] += row_ptr[i-1];
	}

	// coo_col to col_idx
	int index;
	if (num_nnz % 2 == 0){
		index = num_nnz / 2;
	}
	else{
		index = num_nnz / 2 + 1;
	}
	
	uint8_t *col_idx = (uint8_t *)malloc(index * sizeof(uint8_t));
	if (num_nnz % 2 ==1) coo_col[num_nnz++] = 0;
	
	for (i=0; i<num_nnz; i=i+2){
	col_idx[i/2] = (coo_col[i] << 4) | coo_col[i+1];
	}
	
	// HW Data Transfer & Multiplication
		printf("* input copy to onchip M10K memory\n");
        clock_gettime(CLOCK_MONOTONIC, &begin2);
        memcpy((void *)in_vector_ptr, in_vector, 16*2);
        memcpy((void *)mat_vector_ptr, value, num_nnz*2);
        memcpy((void *)row_ptr_ptr, row_ptr, 17);
        memcpy((void *)col_idx_ptr, col_idx, index);
        clock_gettime(CLOCK_MONOTONIC, &end2);	
	
		printf("* polling\n");
        clock_gettime(CLOCK_MONOTONIC, &begin3);
        *(onchip_ptr) = 1;
        while(*(onchip_ptr) != 0)
        {
                ;
        }
        clock_gettime(CLOCK_MONOTONIC, &end3);
        printf("* HW end\n");
	
	//
		printf("[SW output] ");
		for(i=0; i<16; i++)
        {
            printf("%f  ", *(result_sw + i));
        }
		printf("\n");
		printf("[HW output] ");
		for(i=0; i<512; i++)
        {
                // 32비트 정수를 부동 소수점 숫자로 변환하여 출력
                uint32_t int_value = *(onchip_ptr + i);
                __fp16 float_values[2];
                memcpy(float_values, &int_value, sizeof(__fp16) * 2);

                // 두 개의 부동 소수점 숫자를 출력
                printf("%f ", (float)float_values[0]);
                printf("%f ", (float)float_values[1]);
        }
		
	
	free(coo_row);
	free(coo_col);
	free(value);
	free(col_idx);
	
	return 0;
}
