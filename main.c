#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <quadmath.h>

#include <immintrin.h>

#ifdef __cplusplus
extern "C" {
#endif
    /**
     *  Performs operation on each pair of __float128 in vectors.
     *  count is number of elements in each vector.
     */
    void quadruple_add_avx(int count, __float128 *a, __float128 *b, __float128 *out);
    void quadruple_sub_avx(int count, __float128 *a, __float128 *b, __float128 *out);
    void quadruple_mul_avx(int count, __float128 *a, __float128 *b, __float128 *out);
    void quadruple_div_avx(int count, __float128 *a, __float128 *b, __float128 *out);
#ifdef __cplusplus
}
#endif

/**
 *  Declarations for functions with default GCC quadruple implementation.
 */
void quadruple_add_gcc(int count, __float128 *a, __float128 *b, __float128 *out);
void quadruple_sub_gcc(int count, __float128 *a, __float128 *b, __float128 *out);
void quadruple_mul_gcc(int count, __float128 *a, __float128 *b, __float128 *out);
void quadruple_div_gcc(int count, __float128 *a, __float128 *b, __float128 *out);

/* pointer to function perfoming single operation on vector of quadruples */
typedef void(*operation_ptr)(int count, __float128 *a, __float128 *b, __float128 *out);

__float128* alloc_f128_array(int count);
void free_f128_array(__float128 *data);

void generate_data(int count, __float128 begin, __float128 *array);
void display_max_error(int count, __float128 *first, __float128 *second);

/* type of operation */
typedef enum { OP_ADD, OP_SUB, OP_MUL, OP_DIV, OP_COUNT } operation_t;
operation_t operation_from_string(const char *str);

void display_help();

void display_time(clock_t beg, clock_t end, const char *description);

int main(int argc, char *argv[]) {
    operation_ptr avx_impl[OP_COUNT] = {
        &quadruple_add_avx,
        &quadruple_sub_avx,
        &quadruple_mul_avx,
        &quadruple_div_avx,
    };
    operation_ptr gcc_impl[OP_COUNT] = {
        &quadruple_add_gcc,
        &quadruple_sub_gcc,
        &quadruple_mul_gcc,
        &quadruple_div_gcc,
    };

    if (argc < 5) {
        display_help();
        printf("Not enough arguments\n");
        return -1;
    }

    const char *operation = argv[1];
    const char *count_str = argv[2];
    const char *rep_count_str = argv[3];
    const char *backend = argv[4];

    operation_t op = operation_from_string(operation);
    if (op == OP_COUNT) {
        display_help();
        printf("Unknwon command\n");
        return -2;
    }

    int count = atoi(count_str);
    if (count <= 0) {
        printf("Count has to be greater than zero\n");
        return -3;
    }

    int rep_count = atoi(rep_count_str);
    if (rep_count <= 0) {
        printf("REP_COUNT has to be greater than zero\n");
        return -3;
    }

    clock_t generate_begin = clock();

    __float128 *a = alloc_f128_array(count);
    __float128 *b = alloc_f128_array(count);
    __float128 *out = alloc_f128_array(count);
    __float128 *tmp = alloc_f128_array(count);

    generate_data(count, 1.0Q, a);
    generate_data(count, 2.0Q, b);

    clock_t calculate_begin = clock();
    display_time(generate_begin, calculate_begin, "Generation");

    int result = 0;
    while (rep_count --> 0) {
        if (strcmp(backend, "gcc") == 0) {
            gcc_impl[op](count, a, b, out);
        } else if (strcmp(backend, "avx") == 0) {
            avx_impl[op](count, a, b, out);
        } else if (strcmp(backend, "avx_checked") == 0) {
            gcc_impl[op](count, a, b, out);
            avx_impl[op](count, a, b, tmp);
            display_max_error(count, out, tmp);
        } else {
            display_help();
            printf("Unknwon backend\n");
            result = -4;
            break;
        }
    }

    clock_t measure_end = clock();
    display_time(calculate_begin, measure_end, "Calculation");

    free_f128_array(tmp);
    free_f128_array(out);
    free_f128_array(b);
    free_f128_array(a);
	return result;
}

void quadruple_add_gcc(int count, __float128 *a, __float128 *b, __float128 *out) {
    int i;
    for (i = 0; i < count; ++i) {
        out[i] = a[i] + b[i];
    }
}

void quadruple_sub_gcc(int count, __float128 *a, __float128 *b, __float128 *out) {
    int i;
    for (i = 0; i < count; ++i) {
        out[i] = a[i] - b[i];
    }
}

void quadruple_mul_gcc(int count, __float128 *a, __float128 *b, __float128 *out) {
    int i;
    for (i = 0; i < count; ++i) {
        out[i] = a[i] * b[i];
    }
}

void quadruple_div_gcc(int count, __float128 *a, __float128 *b, __float128 *out) {
    int i;
    for (i = 0; i < count; ++i) {
        out[i] = a[i] / b[i];
    }
}

__float128* alloc_f128_array(int count) {
    if (count & 1) { // ensure that avx implementation doesn't have to do special case for last element
        ++count;
    }
    return aligned_alloc(32, count * sizeof(__float128));
}

void free_f128_array(__float128 *data) {
    free(data);
}

void generate_data(int count, __float128 begin, __float128 *array) {
    int i;
    __float128 curr = begin;
    for (i = 0; i < count; ++i) {
        curr *= -1.00005Q;
        array[i] = begin; //curr;
    }
}

void display_max_error(int count, __float128 *first, __float128 *second) {
    int i;
    char buffer[128];
    __float128 max_error = 0.0Q;

    for (i = 0; i < count; ++i) {
        max_error = fmaxq(max_error, fabsq(first[i] - second[i]));
    }

    quadmath_snprintf(buffer, sizeof(buffer), "%#Qe", max_error);
    printf("Max error = %s\n", buffer);
}

operation_t operation_from_string(const char *str) {
    if (strcmp(str, "add") == 0) {
        return OP_ADD;
    } else if (strcmp(str, "sub") == 0) {
        return OP_SUB;
    } else if (strcmp(str, "mul") == 0) {
        return OP_MUL;
    } else if (strcmp(str, "div") == 0) {
        return OP_DIV;
    } else {
        return OP_COUNT;
    }
}

void display_help() {
    printf(
        "Usage: quadruple COMMAND [parameters...]\n\n"
        "Supported commands:\n"
        "add N REP_COUNT BACKED - performs addition of N elements with specified backend\n"
        "sub N REP_COUNT BACKED - performs subtraction of N elements with specified backend\n"
        "mul N REP_COUNT BACKED - performs multiplication of N elements with specified backend\n"
        "div N REP_COUNT BACKED - performs division of N elements with specified backend\n"
        "\n"
        "N is size of array\n"
        "\n"
        "REP_COUNT is number of repetitions of operations\n"
        "\n"
        "BACKED is one of:\n"
        "gcc - uses default gcc implementation\n"
        "avx - uses avx implementation (assembly)\n"
        "avx_checked - uses avx backed and checks output with gcc backend\n\n"
    );
}

void display_time(clock_t beg, clock_t end, const char *description) {
    long double diff = (long double)(end - beg);
    long double seconds = diff / (long double)CLOCKS_PER_SEC;
    printf("%s: %Lf\n", description, seconds);
}
