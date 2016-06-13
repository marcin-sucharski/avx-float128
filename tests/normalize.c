#include <immintrin.h>
#include <x86intrin.h>
#include <stdint.h>
#include <stdio.h>
#include <memory.h>

#ifdef __cplusplus
extern "C" {
#endif
    __m256i test_normalize(__m256i value, __m256i *outExp);
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
    printf("Expected: 0x%016lx 0x%016lx\n", expected.data[0], expected.data[1]);
    printf("Got     : 0x%016lx 0x%016lx\n", result.data[0], result.data[1]);
    return 1;
}

int main() {
    int128_data_t values[] = {
        {{0x0, 0x0}},
        {{0x0, 0x0001FFFFFFFFFFFF}},
        {{0x0, 0x0008FFFFFFFFFFFF}}
    };
    int128_data_t result_frac[] = {
        {{0x0, 0x0}},
        {{0x0, 0x0000FFFFFFFFFFFF}},
        {{0xE000000000000000, 0x00001FFFFFFFFFFF}}
    };
    int128_data_t result_exp[] = {
        {{0x0, 0x0}},
        {{0x0, 0x0}},
        {{0x0, 0x0003000000000000}}
    };

    int count = sizeof(values) / sizeof(values[0]);
    for (int i = 0; i < count; ++i) {
        for (int j = i; j < count; ++j) {
            int128_data_t a = values[i];
            int128_data_t b = values[j];
            int128_data_t a_frac = result_frac[i];
            int128_data_t b_frac = result_frac[j];
            int128_data_t a_exp = result_exp[i];
            int128_data_t b_exp = result_exp[j];

            int128_data_t vals[2] = {a, b};

            __m256i in_vals;
            memcpy(&in_vals, vals, sizeof(vals));

            __m256i outExp;
            __m256i out = test_normalize(in_vals, &outExp);
            int128_data_t out_data[2], out_exp[2];
            memcpy(out_data, &out, sizeof(out));
            memcpy(out_exp, &outExp, sizeof(outExp));

            if (check_result(out_data[0], a_frac, i, j, 0) ||
                check_result(out_data[1], b_frac, i, j, 1) ||
                check_result(out_exp[0], a_exp, i, j, 2) ||
                check_result(out_exp[1], b_exp, i, j, 3)) {
                return 0;
            }
        }
    }

    printf("OK\n");
    return 0;
}
