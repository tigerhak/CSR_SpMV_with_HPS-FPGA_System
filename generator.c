#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <stdint.h>

int main(void) {
    int num_nnz;
	int i;
	
	srand(time(NULL));
	
    printf("num_nnz? ");
    scanf("%d", &num_nnz);

    if (num_nnz >= 256 || num_nnz < 0) {
        printf("[ERROR] num_nnz should be in the range 0~255\n");
        return 1;
    }

    // 생성할 COO 행렬 데이터를 위한 배열 할당
    uint8_t *coo_row = (uint8_t *)malloc(num_nnz * sizeof(uint8_t));
    uint8_t *coo_col = (uint8_t *)malloc(num_nnz * sizeof(uint8_t));
    __fp16 *value = (__fp16 *)malloc(num_nnz * sizeof(__fp16));

    // COO 행렬 초기화
    srand(time(NULL));
    for (i = 0; i < num_nnz; i++) {
        coo_row[i] = i / 16;
        coo_col[i] = i % 16;
		value[i] = 7.7 + i;
    }

    // 생성된 COO 행렬을 파일에 저장
    FILE *matrixFile = fopen("/home/linaro/matrix.txt", "w");
    if (matrixFile == NULL) {
        printf("[ERROR] Unable to write to matrix.txt\n");
        return 1;
    }
	
	fprintf(matrixFile, "%hhu\n", num_nnz);
    for (i = 0; i < num_nnz; i++) {
        fprintf(matrixFile, "%hhu %hhu %f\n", coo_row[i], coo_col[i], (float)value[i]);
    }

    fclose(matrixFile);

    // 할당된 메모리 해제
    free(coo_row);
    free(coo_col);
    free(value);

    return 0;
}
