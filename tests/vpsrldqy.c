#include <immintrin.h>
#include <x86intrin.h>
#include <stdint.h>
#include <stdio.h>
#include <memory.h>

#ifdef __cplusplus
extern "C" {
#endif
    __m256i test_vpsrldqy(__m256i a, __m256i b);
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

int main(int argc, char *argv[]) {
    int i = 0;
    int128_data_t values[] = {
        {{0x0, 0x0}},
        {{0x0, 0x0}},
        {{0x1, 0x0}},
        {{0x1, 0x0}},
        {{0x1, 0x1}},
        {{0x1, 0x1}},
        {{0x1, 0x1}},
        {{0x0, 0x0008FFFFFFFFFFFF}}
    };
    int128_data_t shifts[] = {
        {{0, 0}},
        {{1, 0}},
        {{0, 0}},
        {{1, 0}},
        {{64, 0}},
        {{65, 0}},
        {{1, 0}},
        {{0x3, 0x0}}
    };
    int128_data_t results[] = {
        {{0x0, 0x0}},
        {{0x0, 0x0}},
        {{0x1, 0x0}},
        {{0x0, 0x0}},
        {{0x1, 0x0}},
        {{0x0, 0x0}},
        {{0x8000000000000000, 0x0}},
        {{0xE000000000000000, 0x00011FFFFFFFFFFF}}
    };

    if (argc == 2) {
        i = atoi(argv[1]);
    }

    int count = sizeof(values) / sizeof(values[0]);
    for (; i < count; ++i) {
        for (int j = i; j < count; ++j) {
            int128_data_t a = values[i];
            int128_data_t b = values[j];
            int128_data_t count_a = shifts[i];
            int128_data_t count_b = shifts[j];
            int128_data_t result_a = results[i];
            int128_data_t result_b = results[j];

            int128_data_t vals[2] = {a, b};
            int128_data_t counts[2] = {count_a, count_b};

            __m256i in_vals, in_counts;
            memcpy(&in_vals, vals, sizeof(vals));
            memcpy(&in_counts, counts, sizeof(counts));

            __m256i out = test_vpsrldqy(in_vals, in_counts);
            int128_data_t out_data[2];
            memcpy(out_data, &out, sizeof(out));

            if (check_result(out_data[0], result_a, i, j, 0) || check_result(out_data[1], result_b, i, j, 1)) {
                return 0;
            }
        }
    }

    printf("OK\n");
    return 0;
}
