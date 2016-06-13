#include <immintrin.h>
#include <x86intrin.h>
#include <stdint.h>
#include <stdio.h>
#include <memory.h>

#ifdef __cplusplus
extern "C" {
#endif
    __m256i test_efrac(__m256i value);
#ifdef __cplusplus
}
#endif

typedef union {
    uint64_t data[2];
    __int128_t  value;
} int128_data_t;

int check_result(__int128_t result, __int128_t expected, int i, int j) {
    if (result == expected) {
        return 0;
    }
    printf("Invalid result for case [%d, %d]\n", i, j);
    return 1;
}

int main() {
    int128_data_t values[] = {
        {{0x0, 0x0}},
        {{0xFFFFFFFFFFFFFFFF, 0x7000FFFFFFFFFFFF}},
        {{0x0000000000000001, 0x0000000000000000}},
        {{0x0000000000000000, 0x0000800000000000}}
    };
    int128_data_t results[] = {
        {{0x0, 0x0}},
        {{0xFFFFFFFFFFFFFFFF, 0x0001FFFFFFFFFFFF}},
        {{0x0000000000000001, 0x0001000000000000}},
        {{0x0000000000000000, 0x0001800000000000}}
    };

    int count = sizeof(values) / sizeof(values[0]);
    for (int i = 0; i < count; ++i) {
        for (int j = i; j < count; ++j) {
            __int128_t a = values[i].value;
            __int128_t b = values[j].value;
            __int128_t result_a = results[i].value;
            __int128_t result_b = results[j].value;

            __int128_t vals[2] = {a, b};

            __m256i in_vals;
            memcpy(&in_vals, vals, sizeof(vals));

            __m256i out = test_efrac(in_vals);
            __int128_t out_data[2];
            memcpy(out_data, &out, sizeof(out));

            if (check_result(out_data[0], result_a, i, j) || check_result(out_data[1], result_b, j, i)) {
                return 0;
            }
        }
    }

    printf("OK\n");
    return 0;
}
