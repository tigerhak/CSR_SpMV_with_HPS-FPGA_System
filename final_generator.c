#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <stdint.h>

int main(void) {
    int num_nnz, key;
    int i, j;
    
    srand(time(NULL));

    printf("num_nnz? ");
    scanf("%d", &num_nnz);
    printf("key? ");
    scanf("%d", &key);

    if (num_nnz >= 256 || num_nnz < 0) {
        printf("[ERROR] num_nnz should be in the range 0~255\n");
        return 1;
    }

    uint8_t *coo_row = (uint8_t *)malloc(num_nnz * sizeof(uint8_t));
    uint8_t *coo_col = (uint8_t *)malloc(num_nnz * sizeof(uint8_t));
    __fp16 *value = (__fp16 *)malloc(num_nnz * sizeof(__fp16));
	__fp16 vector[16];
    
    int row[16] = {0};
    int sum = 0;
    int atp1 = 0;
    int a = 0;
    
    while (num_nnz != sum) {
        sum = 0;
        for (i = 0; i < 16; i++) {
            row[i] = rand() % key;
            sum = sum + row[i];
        }
        atp1++;
        if (atp1 > 10000000) {
            printf("[ERROR] Unable to make row-partition\n");
            return 1;
        }
    }
    
    float matrix[16][16] = {0.0};
    
    int used_cols[16] = {0};

    for(i = 0; i < 16; i++) {
        for (j = 0; j < row[i]; j++) {
            int col;
            int atp2 = 0;
            do {
                col = rand() % 16;
                atp2++;
                if (used_cols[i] & (1 << col)) {
                    col = -1;
                }
            } while (col == -1 && atp2 < 10000000);
            if (col == -1) {
                printf("[ERROR] Unable to make col-partition\n");
                return 1;
            }

            matrix[i][col] = (__fp16)(10.0 * rand() / (double)RAND_MAX);
            used_cols[i] |= (1 << col);

            coo_row[a] = i;
            coo_col[a] = col;
            value[a] = matrix[i][col];
            a++;
        }
    }
	
	for (i = 0; i < 16; i++) {
        vector[i] = (__fp16)(10.0 * rand() / (double)RAND_MAX);
    }

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

    FILE *vectorFile = fopen("/home/linaro/vector.txt", "w");
    if (vectorFile == NULL) {
        printf("[ERROR] Unable to write to vector.txt\n");
        return 1;
    }

    for (i = 0; i < 16; i++) {
        fprintf(vectorFile, "%f\n", (float)vector[i]);
    }

    fclose(vectorFile);

    free(coo_row);
    free(coo_col);
    free(value);

    return 0;
}
