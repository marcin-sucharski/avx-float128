#include <immintrin.h>
#include <x86intrin.h>
#include <stdint.h>
#include <stdio.h>
#include <memory.h>

#ifdef __cplusplus
extern "C" {
#endif
    __m256i test_vpslldqy(__m256i a, __m256i b);
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

int main(int argc, char *argv[]) {
    int i = 0;
    int128_data_t values[] = {
        {{0x0, 0x0}},
        {{0x0, 0x0}},
        {{0x1, 0x0}},
        {{0x0, 0x1}},
        {{0x1, 0x1}},
        {{0x1, 0x1}}
    };
    int128_data_t shifts[] = {
        {{0, 0}},
        {{1, 0}},
        {{0, 0}},
        {{1, 0}},
        {{64, 0}},
        {{65, 0}}
    };
    int128_data_t results[] = {
        {{0x0, 0x0}},
        {{0x0, 0x0}},
        {{0x1, 0x0}},
        {{0x0, 0x2}},
        {{0x0, 0x1}},
        {{0x0, 0x0}}
    };

    if (argc == 2) {
        i = atoi(argv[1]);
    }

    int count = sizeof(values) / sizeof(values[0]);
    for (; i < count; ++i) {
        for (int j = i; j < count; ++j) {
            __int128_t a = values[i].value;
            __int128_t b = values[j].value;
            __int128_t count_a = shifts[i].value;
            __int128_t count_b = shifts[j].value;
            __int128_t result_a = results[i].value;
            __int128_t result_b = results[j].value;

            __int128_t vals[2] = {a, b};
            __int128_t counts[2] = {count_a, count_b};

            __m256i in_vals, in_counts;
            memcpy(&in_vals, vals, sizeof(vals));
            memcpy(&in_counts, counts, sizeof(counts));

            __m256i out = test_vpslldqy(in_vals, in_counts);
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
