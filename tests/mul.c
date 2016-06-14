#include <immintrin.h>
#include <x86intrin.h>
#include <stdint.h>
#include <stdio.h>
#include <memory.h>
#include <quadmath.h>

#ifdef __cplusplus
extern "C" {
#endif
    void quadruple_mul_avx(int count, __float128 *a, __float128 *b, __float128 *out);
#ifdef __cplusplus
}
#endif

typedef union {
    uint64_t data[2];
    __int128_t  value;
} int128_data_t;

int check_result(int128_data_t result, int128_data_t expected, int i, int j, int test) {
    if (result.value == expected.value) {
        return 0;
    }
    printf("Invalid result for case [%d, %d, %d]\n", i, j, test);
    printf("%-10s: 0x%016lx 0x%016lx\n", "Expected", expected.data[0], expected.data[1]);
    printf("%-10s: 0x%016lx 0x%016lx\n", "Got", result.data[0], result.data[1]);
    return 1;
}

int main(int argc, char *argv[]) {
    int i = 0;
    __float128 values[] = {
        1.0Q,
        0.0Q,
        2.0Q,
        10.0Q,
        0.5Q
    };

    if (argc == 2) {
        i = atoi(argv[1]);
    }

    int count = sizeof(values) / sizeof(values[0]);
    for (; i < count; ++i) {
        for (int j = i; j < count; ++j) {
            __attribute__((aligned(32))) __float128 a[2] = {values[i], 0.0Q}, b[2] = {values[j], 0.0Q};
            __float128 result = a[0] * b[0];

            __attribute__((aligned(32))) __float128 out[2];
            quadruple_mul_avx(2, a, b, out);

            int128_data_t result_data, expected_result_data;
            memcpy(&result_data, out, sizeof(result_data));
            memcpy(&expected_result_data, &result, sizeof(expected_result_data));

            if (check_result(result_data, expected_result_data, i, j, 0)) {
                int128_data_t ad, bd;
                memcpy(&ad, a, sizeof(ad));
                memcpy(&bd, b, sizeof(bd));
                printf("%-10s: 0x%016lx 0x%016lx\n", "A", ad.data[0], ad.data[1]);
                printf("%-10s: 0x%016lx 0x%016lx\n", "B", bd.data[0], bd.data[1]);
                return 0;
            }
        }
    }

    printf("OK\n");
    return 0;
}
