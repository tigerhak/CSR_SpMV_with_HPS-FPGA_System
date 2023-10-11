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

        in_vector_ptr   =       onchip_ptr + 120;
        mat_vector_ptr  =       onchip_ptr + 128;
        row_ptr_ptr             =       onchip_ptr + 256;
        col_idx_ptr             =       onchip_ptr + 264;
        result_ptr              =       onchip_ptr + 384;

        uint8_t num_nnz;

        FILE *matrixFile = fopen("/home/linaro/matrix.txt", "r");
        if (matrixFile == NULL) {
                printf("[ERROR] Unable to read matrix.txt\n");
                return 1;
        }

        fscanf(matrixFile, "%hhu", &num_nnz);

        uint8_t *coo_row = (uint8_t *)malloc(num_nnz * sizeof(uint8_t));
        uint8_t *coo_col = (uint8_t *)malloc(num_nnz * sizeof(uint8_t));
        __fp16 *value = (__fp16 *)malloc(num_nnz * sizeof(__fp16));

        for (i = 0; i < num_nnz; i++) {
                int row, col;
                float val;
                if (fscanf(matrixFile, "%d %d %f", &row, &col, &val) != 3) {
                        printf("[ERROR] Failed to read matrix data from matrix.txt\n");
                        return 1;
                }
                coo_row[i] = (uint8_t)row;
                coo_col[i] = (uint8_t)col;
                value[i] = (__fp16)val;
        }
        fclose(matrixFile);

        FILE *vectorFile = fopen("/home/linaro/vector.txt", "r");
        if (vectorFile == NULL) {
                printf("[ERROR] Unable to read vector.txt\n");
                return 1;
        }

        float inputss[16];
        __fp16 in_vector[16];

        // "vector.txt" 파일에서 데이터를 읽어와서 vector 배열에 저장
        for (i = 0; i < 16; i++) {
                if (fscanf(vectorFile, "%f", &inputss[i]) != 1) {
                        printf("[ERROR] Failed to read data from vector.txt\n");
                        fclose(vectorFile);
                        return 1;
                }
        }

        // "vector.txt" 파일 닫기
        fclose(vectorFile);
	
		for (i=0; i<16; i++)
		{
			in_vector[i] = (__fp16)inputss[i];
		}

        // SW Multiplication
        clock_gettime(CLOCK_MONOTONIC, &begin0);
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
        clock_gettime(CLOCK_MONOTONIC, &end0);
		

        clock_gettime(CLOCK_MONOTONIC, &begin1);
        // COO to CSR encoding
        uint8_t row_ptr[32];

        // Initialize row_ptr to all 0
        for(i=0; i<32; i++){
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
        clock_gettime(CLOCK_MONOTONIC, &end1);

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
                col_idx[i/2] = coo_col[i] + (coo_col[i+1]<<4);
        }

        // HW Data Transfer & Multiplication

        clock_gettime(CLOCK_MONOTONIC, &begin2);
        memcpy((void *)in_vector_ptr, in_vector, 16*2);
        memcpy((void *)mat_vector_ptr, value, num_nnz*2);
        memcpy((void *)row_ptr_ptr, row_ptr, 32);
        memcpy((void *)col_idx_ptr, col_idx, num_nnz/2);
        clock_gettime(CLOCK_MONOTONIC, &end2);

        clock_gettime(CLOCK_MONOTONIC, &begin3);
        *(onchip_ptr) = 1;
        while(*(onchip_ptr) != 0)

        {
                ;
        }

        clock_gettime(CLOCK_MONOTONIC, &end3);

		float matrix[16][16] = {0.0};
		
		for(i=0; i<num_nnz; i++){
			int a = coo_row[i];
			int b = coo_col[i];
			float val = (float)value[i];
			matrix[a][b] = val;
		}
		
		printf("\n**********Sparse Matrix X Dense Vector**********\n\n");
		for(i=0; i<16; i++){
			for(j=0; j<16; j++){
				if (matrix[i][j] == 0.0){
					printf("0        ");
				} else {
					printf("%f ",matrix[i][j]);
				}
			}
			printf("   %f \n", inputss[i]);
		}
		printf("[NOTICE] The Matrix Sparsity is %.1f %%\n", 100 - (float)num_nnz/256*100); 

		printf("\n**********CSR Encoding**********\n\n");
		printf("[row_ptr] ");
		for(i=0; i<32; i++){
			printf("%hhu ", row_ptr[i]);
		}
		printf("\n[col_idx] ");
		for(i=0; i<num_nnz/2; i++){
			printf("%hhu ", coo_col[i]);
		}
		
		printf("**********Output**********\n\n");
		printf("[SW output] ");
		for(i=0; i<16; i++){
			printf("%f ", result_sw[i]);
		}
		printf("\n[HW output] ");
		for(i=0; i<8; i++){
			uint32_t int_values = *(result_ptr + i);
			__fp16 float_value[2];
			memcpy(float_value, &int_values, sizeof(__fp16)*2);
			printf("%f %f ", (float)float_value[0], (float)float_value[1]);
		}
		printf("\n");

        // make output.txt
        FILE *outputFile = fopen("/home/linaro/output.txt", "w");
        if (outputFile == NULL)
        {
                printf("[ERROR] write in output.txt un-available");
                return (1);
        }

        fprintf(outputFile, "[SW SpMV]\n");
        for (i=0; i<16; i++)
        {
                fprintf(outputFile, "%f\n", result_sw[i]);
        }
        fprintf(outputFile, "\n");
		
		double x1, x2;
		x1 = 0.0;
		x2 = 0.0;

        fprintf(outputFile, "[HW SpMV]\n");
        for (i = 0; i < 8; i++) {
                uint32_t int_value = *(result_ptr + i);
                __fp16 float_values[2];
                memcpy(float_values, &int_value, sizeof(__fp16) * 2);
                fprintf(outputFile, "%f\n%f\n", (float)float_values[0], (float)float_values[1]);
				
				if ((float)result_sw[2*i+1] == 0.0) x1 += 0.0;
				else x1 += (fabs((float)result_sw[2*i+1] - (float)float_values[1]) / (float)result_sw[2*i+1]);
				//printf("%f\n", x1);
				
				if ((float)result_sw[2*i] == 0.0) x2 += 0.0;
				else x2 += (fabs((float)result_sw[2*i] - (float)float_values[0]) / (float)result_sw[2*i]);
				//printf("%f\n", x2);
				
        }
		
		printf("\n**********Evaluation**********\n");
		double accuracy;
		accuracy = 100 - ((x1+x2) / 16)*100;
		printf("\n[HW SpMV accuracy]		%.1f %%\n", accuracy);

        fprintf(outputFile, "\n");
        printf("\n");

        fclose(outputFile);

        free(coo_row);
        free(coo_col);
        free(value);
        free(col_idx);

        a = ((double)(end0.tv_sec - begin0.tv_sec)*1000000) + ((double)((end0.tv_nsec - begin0.tv_nsec) / 1000));
        b = ((double)(end1.tv_sec - begin1.tv_sec)*1000000) + ((double)((end1.tv_nsec - begin1.tv_nsec) / 1000));
        c = ((double)(end2.tv_sec - begin2.tv_sec)*1000000) + ((double)((end2.tv_nsec - begin2.tv_nsec) / 1000));
        d = ((double)(end3.tv_sec - begin3.tv_sec)*1000000) + ((double)((end3.tv_nsec - begin3.tv_nsec) / 1000));

		printf("[SW SpMV performance]		%.1lf us\n\n", a);
		printf("[HW SpMV performance]		%.1lf us\n", d);
		printf("[HW encoding performance]	%.1lf us\n", b);
		printf("[SW to HW data transfer]	%.1lf us\n\n", c);

        return 0;
}
