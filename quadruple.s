section .text

global quadruple_add_avx
global quadruple_sub_avx
global quadruple_mul_avx
global quadruple_div_avx

global test_adddq
global test_vpsrldqy
global test_vpslldqy
global test_efrac
global test_normalize

%define FRAC_BITS 112
%define EXP_BITS 15

; Adds %2 to %3 and stores result in %1
; %4, %5, %6 are temporary
;
; %2 = [a2, a1; c2, c1]
; %3 = [b2, b1; d2, d1]
;
; Result:
; %1 = [a+b; c+d]
%macro vpadddq 5
	vpaddq		%1,	%2,	%3		; %1 = [a2+b2, a1+b1; c2+d2, c1+d1]
	vpand		%4,	%1,	[first_64_bits]	; %4 = [0, a1+b1; 0, c1+d1]
	vpslldq		%4,	%4,	8		; %4 = [a1+b1, 0; c1+d1, 0]
	vpslldq		%5,	%2,	8		; %5 = [a1, 0; c1, 0]
	vpxor		%4,	%4,	[adddq_sgn_xor]
	vpxor		%5,	%5,	[adddq_sgn_xor]
	vpcmpgtq	%4,	%5,	%4		; %4 = [a1+b1 < a1, 0; c1+d1 < c1, 0]
	vpsubq		%1,	%1,	%4		; %1 = result
%endmacro

; Shifts right double qword by specified number of bits
; %1 - output
; %2 - value to be shifted
; %3 - number of bits
; %4, %5 - tmp
%macro vpsrldqy 5
	vmovdqa		%5,	[positive_64]
	vpminud		%4,	%3,	[first_8_bits]
	vpshufd		%4,	%4,	11001100b
	vpsrlvq		%1,	%2,	%4
	vpsubq		%4,	%5,	%4
	vpsllvq		%4,	%2,	%4
	vpshufd		%4,	%4,	01001110b
	vpand		%4,	%4,	[first_64_bits]
	vpor		%1,	%1,	%4
%endmacro

; Shifts left double qword by specified number of bits
; %1 - output
; %2 - value to be shifted
; %3 - number of bits
; %4, %5 - tmp
%macro vpslldqy 5
	vmovdqa		%5,	[positive_64]
	vpminud		%4,	%3,	[first_8_bits]
	vpshufd		%4,	%4,	11001100b
	vpsllvq		%1,	%2,	%4
	vpsubq		%4,	%5,	%4
	vpsrlvq		%4,	%2,	%4
	vpshufd		%4,	%4,	01001110b
	vpand		%4,	%4,	[second_64_bits]
	vpor		%1,	%1,	%4
%endmacro

; Extracts fraction from quadruple
; %1 - output
; %2 - quadruple tuple
; %3, %4 - temp
%macro efrac 4
	vpand		%1,	%2,	[zero_expsgn]
	vpxor		%4,	%4,	%4
	vpand		%3,	%2,	[zero_sign]
	vpcmpeqq	%3,	%3,	%4
	vpshufd		%4,	%3,	01001110b
	vpand		%3,	%3,	%4
	vpshufd		%3,	%3,	0
	vpcmpeqq	%4,	%4,	%4
	vpxor		%3,	%3,	%4
	vpand		%4,	%3,	[hidden_one]
	vpor		%1,	%1,	%4
%endmacro

; Calculates exponent difference and sorts values by exponent
; %1 - [out] expdiff
; %2 - [out] values with greater exponents
; %3 - [out] values with lower exponents
; %4 - first values
; %5 - second values
; %6,%7 - temp
%macro expdiff 7
	vpand		%1,	%4,	[zero_sign]	; remove sign
	vpand		%2,	%5,	[zero_sign]
	vpsrldq		%1,	%1,	FRAC_BITS/8	; move exp to left (remove frac)
	vpsrldq		%2,	%2,	FRAC_BITS/8
	vpsubsw		%6,	%1,	%2		; subtract exponents
	vpabsw		%6,	%6			; absolute value of exp diff
	vpmaxud		%1,	%1,	%2
	vpcmpeqd	%1,	%1,	%2		; compare fractions
	vpshufd		%1,	%1,	0
	vpblendvb	%2,	%4,	%5,	%1	; sort
	vpcmpeqd	%7,	%7,	%7		; 0xFF...FF in %7
	vpxor		%1,	%1,	%7		; negate %1
	vpblendvb	%3,	%4,	%5,	%1
	vmovdqa		%1,	%6			; save absolute exp diff to %1
	; %2 and %3 should be sorted according to exponent (exp3 > exp4)
	; %1 holds exp3-exp4
%endmacro

; Convert values to 2C, but does not add one's (returns them in registers)
; %1 - [out] first pair of values
; %2 - [out] second pair of values
; %3 - [out] +1 for first values
; %4 - [out] +1 for second values
; %5 - first pair of fractions
; %6 - second pair of fractions
; %7 - original values with sign for first values
; %8 - original values with sign for second values
; %9 - sign bit constant
%macro to2c 9
	vpand		%3,	%7,	%9
	vpand		%4,	%8,	%9
	vpcmpeqq	%3,	%3,	%9
	vpcmpeqq	%4,	%4,	%9
	vpshufd		%3,	%3,	0xFF		; %3 = ones if %7 negative
	vpshufd		%4,	%4,	0xFF		; %4 = ones if %8 negative

; negate bits if negating
	vpxor		%1,	%5,	%3
	vpxor		%2,	%6,	%4

; positive one if negating, otherwise zero
	vpand		%3,	%3,	[first_bit]
	vpand		%4,	%4,	[first_bit]
%endmacro

; Normalizes fraction
; %1 - in/out fraction
; %2 - out exp change
; %3-8 - temporary ymm
%macro normalize 8
	vmovdqu		[rsp-32],	%1

	lzcnt		r9,		[rsp-8]
	lzcnt		r8,		[rsp-16]
	add		r8,		64
	cmp		r9,		64
	cmove		r9,		r8
	mov		[rsp-48],	r9

	lzcnt		r11,		[rsp-24]
	lzcnt		r10,		[rsp-32]
	add		r10,		64
	cmp		r11,		64
	cmove		r11,		r10
	mov		[rsp-64],	r11

	vpxor		%3,	%3,	%3
	vpcmpeqd	%4,	%4,	%4

	vmovdqu		%2,	[rsp-64]
	vpcmpeqq	%5,	%1,	%3
	vpshufd		%6,	%5,	01001110b
	vpand		%5,	%5,	%6
	vpxor		%5,	%5,	%4
	vpsubd		%2,	%2,	[value_15]
	vpand		%2,	%2,	%5

	vpmuldq		%4,	%2,	%4
	vpmaxsd		%5,	%3,	%2
	vpmaxsd		%6,	%3,	%4
	vmovdqa		%2,	%4

	vpslldqy	%7,	%1,	%5,	%8,	%4
	vpsrldqy	%1,	%7,	%6,	%8,	%4
	vpand		%1,	%1,	[zero_expsgn]
	vpshufd		%2,	%2,	00111111b
	vpshufhw	%2,	%2,	10000000b
%endmacro

; Arguments:
; rdi - count
; rsi - pointer to `a` vector
; rdx - pointer to `b` vector
; rcx - pointer to output vector
;
; Arguments are same for every function.


quadruple_add_avx:
	vpxor		ymm15,	ymm15,	ymm15
	vmovdqu		[rsp-64],	ymm15
; divide count by 2 rounding up
	add	edi,	1
	shr	edi,	1
	align	32
.loop:
; load data
	vmovdqa		ymm0,	[rsi]
	vmovdqa		ymm1,	[rdx]

; exponent diff
; reads: ymm0, ymm1
; out: ymm2 (expdiff), ymm3 (first values), ymm4 (second values)
	expdiff		ymm2,	ymm3,	ymm4,	ymm0,	ymm1,	ymm5,	ymm6

; extract fractions
; reads: ymm3, ymm4, ymm2
; out: ymm5, ymm6
	efrac		ymm5,	ymm3,	ymm7,	ymm8
	efrac		ymm6,	ymm4,	ymm7,	ymm8

; alignment
	vpsrldqy	ymm7,	ymm6,	ymm2,	ymm14,	ymm15
	vmovdqa		ymm6,	ymm7

; convert to 2C
	vmovdqa		ymm15,	[sign]
	to2c		ymm9,	ymm10,	ymm7,	ymm8,	ymm5,	ymm6,	ymm3,	ymm4,	ymm15

; add fractions
; reads: ymm5, ymm6
; out: ymm7
	vpaddq		ymm7,	ymm7,	ymm8
	vpadddq		ymm8,	ymm9,	ymm10,	ymm11,	ymm12
	vpadddq		ymm7,	ymm8,	ymm7,	ymm11,	ymm12

; convert to sign-module
; reads: ymm7
; out: ymm7 (value), ymm8 (sign bit)
	vpand		ymm8,	ymm7,	ymm15		; ymm8 - sign bit
	vpcmpeqd	ymm9,	ymm8,	ymm15
	vpshufd		ymm9,	ymm9,	0xFF		; ymm9 = ones if ymm7 negative

	vpxor		ymm7,	ymm7,	ymm9
	vpand		ymm9,	ymm9,	[first_bit]
	vpadddq		ymm10,	ymm7,	ymm9,	ymm11,	ymm12
	vmovdqa		ymm7,	ymm10

; normalization
	normalize	ymm7,	ymm0,	ymm1,	ymm6,	ymm5,	ymm4,	ymm10,	ymm11

; add sign bit
; reads: ymm7, ymm8
; out: ymm7
	vpor		ymm7,	ymm7,	ymm8

; set exponent
; reads: ymm7, ymm3, ymm0
; out: ymm7
	vpand		ymm8,	ymm3,	[exp]
	vpaddd		ymm8,	ymm8,	ymm0
	vpor		ymm7,	ymm7,	ymm8

; save result
	vmovdqa		[rcx],	ymm7

; loop epilog
	add	rsi,	32
	add	rdx,	32
	add	rcx,	32
	sub	edi,	1
	jnz	.loop
	rep ret


quadruple_sub_avx:
	vpxor		ymm15,	ymm15,	ymm15
	vmovdqu		[rsp-64],	ymm15
; divide count by 2 rounding up
	add	edi,	1
	shr	edi,	1
	align	32
.loop:
; load data
	vmovdqa		ymm0,	[rsi]
	vmovdqa		ymm1,	[rdx]

; negate second
	vpxor		ymm1,	ymm1,	[sign]

; exponent diff
; reads: ymm0, ymm1
; out: ymm2 (expdiff), ymm3 (first values), ymm4 (second values)
	expdiff		ymm2,	ymm3,	ymm4,	ymm0,	ymm1,	ymm5,	ymm6

; extract fractions
; reads: ymm3, ymm4, ymm2
; out: ymm5, ymm6
	efrac		ymm5,	ymm3,	ymm7,	ymm8
	efrac		ymm6,	ymm4,	ymm7,	ymm8

; alignment
	vpsrldqy	ymm7,	ymm6,	ymm2,	ymm14,	ymm15
	vmovdqa		ymm6,	ymm7

; convert to 2C
	vmovdqa		ymm15,	[sign]
	to2c		ymm9,	ymm10,	ymm7,	ymm8,	ymm5,	ymm6,	ymm3,	ymm4,	ymm15

; add fractions
; reads: ymm5, ymm6
; out: ymm7
	vpaddq		ymm7,	ymm7,	ymm8
	vpadddq		ymm8,	ymm9,	ymm10,	ymm11,	ymm12
	vpadddq		ymm7,	ymm8,	ymm7,	ymm11,	ymm12

; convert to sign-module
; reads: ymm7, ymm15
; out: ymm7 (value),
	vpand		ymm8,	ymm7,	ymm15		; ymm8 - sign bit
	vpcmpeqd	ymm9,	ymm8,	ymm15
	vpshufd		ymm9,	ymm9,	0xFF		; ymm9 = ones if ymm7 negative

	vpxor		ymm7,	ymm7,	ymm9
	vpand		ymm9,	ymm9,	[first_bit]
	vpadddq		ymm10,	ymm7,	ymm9,	ymm11,	ymm12
	vmovdqa		ymm7,	ymm10

; normalization
	normalize	ymm7,	ymm0,	ymm1,	ymm6,	ymm5,	ymm4,	ymm10,	ymm11

; add sign bit
; reads: ymm7
; out: ymm7
	vpor		ymm7,	ymm7,	ymm8

; set exponent
; reads: ymm7, ymm3, ymm0
; out: ymm7
	vpand		ymm8,	ymm3,	[exp]
	vpaddd		ymm8,	ymm8,	ymm0
	vpor		ymm7,	ymm7,	ymm8

; save result
	vmovdqa		[rcx],	ymm7

; loop epilog
	add	rsi,	32
	add	rdx,	32
	add	rcx,	32
	sub	edi,	1
	jnz	.loop
	rep ret


quadruple_mul_avx:
	vpxor		ymm15,	ymm15,	ymm15
	vmovdqu		[rsp-64],	ymm15

; divide count by 2 rounding up
	add	edi,	1
	shr	edi,	1
	align	32
.loop:
; load data
	vmovdqa		ymm0,	[rsi]
	vmovdqa		ymm1,	[rdx]

; extract fractions
; reads: ymm0, ymm1
; out: ymm2, ymm3 (first and second pair of fractions)
	efrac		ymm2,	ymm0,	ymm4,	ymm5
	efrac		ymm3,	ymm1,	ymm4,	ymm5

; extract exponents
; reads: ymm0, ymm1
; out: ymm3, ymm4 (first and second pair of exponents)
	vpand		ymm4,	ymm0,	[exp]
	vpand		ymm5,	ymm1,	[exp]

; get new sign
; reads: ymm0, ymm1
; out: ymm14 (new sign)
	vpand		ymm6,	ymm0,	[sign]
	vpand		ymm7,	ymm1,	[sign]
	vpxor		ymm14,	ymm6,	ymm7

; add exponents
; reads: ymm3, ymm4
; out: ymm0 (sum of exponents)
	vpaddw		ymm0,	ymm4,	ymm5
	vpsubw		ymm0,	ymm0,	[exp_bias]

; multiply fractions
; reads: ymm2, ymm3
; writes: ymm15
;
; free: ymm1, ymm4, ymm5, ...
;
; ymm2 = [x4, x3, x2, x1] * 2
; ymm3 = [y4, y3, y2, y1] * 2
	vpshufd		ymm1,	ymm2,	00000000b	; ymm1 = [## x1 ## x1]
	vpshufd		ymm4,	ymm2,	01010101b	; ymm4 = [## x2 ## x2]
	vpshufd		ymm5,	ymm2,	10101010b	; ymm5 = [## x3 ## x3]
	vpshufd		ymm6,	ymm2,	11111111b	; ymm6 = [## x4 ## x4]
	vpshufd		ymm7,	ymm3,	00110001b	; ymm7 = [## y4 ## y2]

	vpmuldq		ymm8,	ymm1,	ymm3		; ymm8 =  [x1*y3, x1*y1]
	vpmuldq		ymm1,	ymm1,	ymm7		; ymm1 =  [x1*y4, x1*y2]
	vpmuldq		ymm9,	ymm4,	ymm3		; ymm9 =  [x2*y3, x2*y1]
	vpmuldq		ymm4,	ymm4,	ymm7		; ymm4 =  [x2*y4, x2*y2]
	vpmuldq		ymm10,	ymm5,	ymm3		; ymm10 = [x3*y3, x3*y1]
	vpmuldq		ymm5,	ymm5,	ymm7		; ymm5 =  [x3*y4, x3*y2]
	vpmuldq		ymm11,	ymm6,	ymm3		; ymm11 = [x4*y3, x4*y1]
	vpmuldq		ymm6,	ymm6,	ymm7		; ymm6 =  [x4*y4, x4*y2]

	vmovdqa		ymm15,	ymm8
	vpsrldq		ymm15,	ymm15,	4

	vpadddq		ymm8,	ymm1,	ymm9,	ymm12,	ymm13
	vpadddq		ymm1,	ymm15,	ymm8,	ymm12,	ymm13
	vpsrldq		ymm15,	ymm1,	4

	vpadddq		ymm8,	ymm4,	ymm10,	ymm12,	ymm13
	vpadddq		ymm1,	ymm15,	ymm8,	ymm12,	ymm13
	vpsrldq		ymm15,	ymm1,	4

	vpadddq		ymm8,	ymm5,	ymm11,	ymm12,	ymm13
	vpadddq		ymm1,	ymm15,	ymm8,	ymm12,	ymm13
	vpsrldq		ymm15,	ymm1,	4

	;int3
	vpadddq		ymm1,	ymm15,	ymm6,	ymm12,	ymm13
	vpslldq		ymm15,	ymm1,	2

; normalize result
	normalize	ymm15,	ymm7,	ymm8,	ymm2,	ymm3,	ymm4,	ymm5,	ymm6
; calc mask for exponent
	vpxor		ymm9,	ymm9,	ymm9
	vpcmpeqq	ymm11,	ymm11,	ymm11
	vpcmpeqq	ymm10,	ymm1,	ymm9
	vpshufd		ymm1,	ymm1,	01001110b
	vpcmpeqq	ymm1,	ymm1,	ymm9
	vpand		ymm1,	ymm1,	ymm10
	vpxor		ymm1,	ymm1,	ymm11
; calc new exponent
	vpaddd		ymm0,	ymm0,	ymm7
	vpand		ymm0,	ymm0,	ymm1
	vpor		ymm15,	ymm15,	ymm14
	vpor		ymm15,	ymm15,	ymm0

; save result
	vmovdqa		[rcx],	ymm15

; loop epilog
	add	rsi,	32
	add	rdx,	32
	add	rcx,	32
	sub	edi,	1
	jnz	.loop
	rep ret


quadruple_div_avx:
	rep ret

; Function for testing addition of 128 bit integers
;
; Arguments:
; ymm0 - first pair of 128 bit integers
; ymm1 - second pair of 128 bit integers
;
; Result in ymm0
test_adddq:
	vpadddq		ymm3,	ymm0,	ymm1,	ymm4,	ymm5
	vmovdqa		ymm0,	ymm3
	rep ret

; Function for testing right bit shift of 128 bit integers.
;
; Arguments:
; ymm0 - pair of integers to be shifted
; ymm1 - number of bits to shift
;
; Result in ymm0
test_vpsrldqy:
	vpsrldqy	ymm2,	ymm0,	ymm1,	ymm3,	ymm5
	vmovdqa		ymm0,	ymm2
	rep ret

; Function for testing left bit shift of 128 bit integers.
;
; Arguments:
; ymm0 - pair of integers to be shifted
; ymm1 - number of bits to shift
;
; Result in ymm0
test_vpslldqy:
	vpslldqy	ymm2,	ymm0,	ymm1,	ymm3,	ymm5
	vmovdqa		ymm0,	ymm2
	rep ret

; Function for testing extract fraction macro.
;
; Arguments:
; ymm0 - quadruple from which fraction should be extracted
;
; Result in ymm0
test_efrac:
	efrac		ymm1,	ymm0,	ymm2, ymm3
	vmovdqa		ymm0,	ymm1
	rep ret

; Function for testing fractin normalization.
;
; Arguments:
; ymm0 - fraction to be normalized
; rdi - pointer to exp change result
;
; Results:
; ymm0 - normalized fraction
; [rdi] - exp change
test_normalize:
	vpxor		ymm15,	ymm15,	ymm15
	vmovdqu		[rsp-64],	ymm15
	normalize	ymm0,	ymm1,	ymm2,	ymm3,	ymm4,	ymm5,	ymm6,	ymm7
	vmovdqu		[rdi],	ymm1
	rep ret

section .data
align 32
	zero_sign: 	dq	0xFFFFFFFFFFFFFFFF, 0x7FFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF, 0x7FFFFFFFFFFFFFFF
	sign:		dq	0x0000000000000000, 0x8000000000000000, 0x0000000000000000, 0x8000000000000000
	zero_expsgn: 	dq	0xFFFFFFFFFFFFFFFF, 0x0000FFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF, 0x0000FFFFFFFFFFFF
	exp:		dq	0x0000000000000000, 0x7FFF000000000000, 0x0000000000000000, 0x7FFF000000000000
	hidden_one: 	dq	0x0000000000000000, 0x0001000000000000, 0x0000000000000000, 0x0001000000000000
	adddq_sgn_xor:	dq	0x8000000000000000, 0x8000000000000000, 0x8000000000000000, 0x8000000000000000
	first_64_bits:	dq	0xFFFFFFFFFFFFFFFF, 0x0000000000000000, 0xFFFFFFFFFFFFFFFF, 0x0000000000000000
	second_64_bits:	dq	0x0000000000000000, 0xFFFFFFFFFFFFFFFF, 0x0000000000000000, 0xFFFFFFFFFFFFFFFF
	first_bit:	dq	0x0000000000000001, 0x0000000000000000, 0x0000000000000001, 0x0000000000000000
	first_8_bits:	dq	0x00000000000000FF, 0x0000000000000000, 0x00000000000000FF, 0x0000000000000000
	positive_64:	dq	0x0000000000000040, 0x0000000000000040, 0x0000000000000040, 0x0000000000000040
	value_15:	dq	0x000000000000000F, 0x0000000000000000, 0x000000000000000F, 0x0000000000000000
	exp_bias:	dq	0x0000000000000000, 0x3fff000000000000, 0x0000000000000000, 0x3fff000000000000
	least_32_bits:	dq	0x000000000000FFFF, 0x0000000000000000, 0x000000000000FFFF, 0x0000000000000000
