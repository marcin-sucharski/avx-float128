#include <immintrin.h>
#include <x86intrin.h>
#include <stdint.h>
#include <stdio.h>
#include <memory.h>

#ifdef __cplusplus
extern "C" {
#endif
    __m256i test_adddq(__m256i a, __m256i b);
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
        {{0x0, 0x1}},
        {{0x8000000000000000, 0x0}},
        {{0x8000000000000000, 0x1}},
        {{0x8000000000000000, 0x8000000000000000}}
    };

    int count = sizeof(values) / sizeof(values[0]);
    for (int i = 0; i < count; ++i) {
        for (int j = i; j < count; ++j) {
            __int128_t a = values[i].value;
            __int128_t b = values[j].value;
            __int128_t result = a + b;

            __int128_t in_a[2] = {a, b};
            __int128_t in_b[2] = {b, a};

            __m256i in_a_val, in_b_val;
            memcpy(&in_a_val, in_a, sizeof(in_a_val));
            memcpy(&in_b_val, in_b, sizeof(in_b_val));

            __m256i out = test_adddq(in_a_val, in_b_val);
            __int128_t out_data[2];
            memcpy(out_data, &out, sizeof(out));

            if (check_result(result, out_data[0], i, j) || check_result(result, out_data[1], j, i)) {
                return -1;
            }
        }
    }

    printf("OK\n");
    return 0;
}
