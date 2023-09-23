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

// H2F BUS BASE OFFSET
#define FPGA_AXI_BASE   0xC0000000
#define FPGA_AXI_SPAN   0x00001000

// ONCHIP BASE OFFSET
#define ONCHIP_OFFSET   0x08000000
#define ONCHIP_SPAN     0x00000fff
#define HPS_ONCHIP_BASE         0xffff0000
#define HPS_ONCHIP_SPAN         0x00010000

volatile unsigned int * onchip_ptr = NULL ;
volatile unsigned int * in_vector_ptr = NULL ;
volatile unsigned int * mat_vector_ptr = NULL ;
volatile unsigned int * row_ptr_ptr = NULL;
volatile unsigned int * col_idx_ptr = NULL;
volatile unsigned int * result_ptr = NULL ;

int fd;

int main(void)
{
	int i,j,k;
	
	if(( fd = open( "/dev/mem", ( O_RDWR | O_SYNC ) ) ) == -1 ){
		printf("[ERROR] could not get FPGA address\n");
		return(1);
	}
	
	onchip_ptr = mmap (NULL, ONCHIP_SPAN, (PROT_READ | PROT_WRITE), MAP_SHARED, fd, FPGA_AXI_BASE + ONCHIP_OFFSET);
	if(onchip_ptr == MAP_FAILED){
		printf("[ERROR] could not get virtual address for onchip SRAM\n");
	}
	
	in_vector_ptr   = onchip_ptr + 120;
    mat_vector_ptr  = onchip_ptr + 128;
    row_ptr_ptr     = onchip_ptr + 256;
    col_idx_ptr 	= onchip_ptr + 264;
    result_ptr   	= onchip_ptr + 384;
	
	printf("[NOTICE] clear result before start\n");
	
	for(i=0; i<9; i++){
		*(result_ptr + i) = 0;
	}
	
	
	
	int num_nnz = 8;
	
	__fp16 in_vector[16] = {1, 3.1, 31, 0.41, 0.18, 6.31, 3, 8, 0, 1.2, 57.1, 31.3, 4.1, 1.2, 75, 31};
    __fp16 mat_vector[8] = {1.03, 5.2, 7, 3.1, 10, 2, 9, 7};
    uint8_t row_ptr[32] = {0, 0, 1, 2, 2, 2, 2, 3, 3, 4, 4, 5, 6, 6, 6, 7, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
    uint8_t col_idx[4] = {0x30, 0x75, 0xdb, 0xfe};
	
	printf("\n@@ result initialize @@\n");
	for(i=0; i<512; i++){
		*(onchip_ptr + i) = 0;
	}
	
	printf("\n@@ result before memcpy @@\n");
        for(i=0; i<512; i++)
        {
                printf("%d  ", *(onchip_ptr + i));
        }
		
	memcpy(in_vector_ptr, in_vector, 16*sizeof(__fp16));
    memcpy(mat_vector_ptr, mat_vector, 8*sizeof(__fp16));
    memcpy(row_ptr_ptr, row_ptr, 32*sizeof(uint8_t));
    memcpy(col_idx_ptr, col_idx, 4*sizeof(uint8_t));
	
	printf("\n@@ result after memcpy @@\n");
        for(i=0; i<512; i++)
        {
                printf("%d  ", *(onchip_ptr + i));
        }
	
	printf("\n");
	
	printf("\nonchip_ptr: %p\n", (void *)onchip_ptr);
	printf("in_vector_ptr: %p\n", (void *)in_vector_ptr);
	printf("mat_vector_ptr: %p\n", (void *)mat_vector_ptr);
	printf("row_ptr_ptr: %p\n", (void *)row_ptr_ptr);
	printf("col_idx_ptr: %p\n", (void *)col_idx_ptr);
	printf("result_ptr: %p\n", (void *)result_ptr);
	
	return 0;
}
