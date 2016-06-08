section .text

global quadruple_add_avx
global quadruple_sub_avx
global quadruple_mul_avx
global quadruple_div_avx

global test_adddq

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
%macro vpadddq 6
	vpcmpeqd	%6,	%6,	%6		; %4 = 0xFF..FF
	vpsrldq		%6,	%6,	8		; %4 = [0, 0xFF..FF; 0, 0xFF..FF]
	vpaddq		%1,	%2,	%3		; %1 = [a2+b2, a1+b1; c2+d2, c1+d1]
	vpand		%4,	%1,	%6		; %4 = [0, a1+b1; 0, c1+d1]
	vpslldq		%5,	%2,	8		; %5 = [a1, 0; c1, 0]
	vpor		%4,	%4,	%5		; %4 = [a1, a1+b1; c1, c1+d1]
	vpxor		%4,	%4,	[adddq_sgn_xor]
	vpand		%5,	%4,	%6
	vpsrldq		%4,	%4,	8
	vpcmpgtq	%6,	%4,	%5		; %6 = [0, a1+b1 < a1; 0, c1+d1 < c1]
	vpslldq		%6,	%6,	8		; %6 = [a1+b1 < a1, 0; c1+d1 < c1, 0]
	vpsubq		%1,	%1,	%6		; %1 = result
%endmacro


; Arguments:
; rdi - count
; rsi - pointer to `a` vector
; rdx - pointer to `b` vector
; rcx - pointer to output vector
;
; Arguments are same for every function.


quadruple_add_avx:
; divide count by 2 rounding up
	add	rdi,	1
	shr	rdi,	1
	align 32
.loop:
; load data
	vmovdqa		ymm0,	[rsi]
	vmovdqa		ymm1,	[rdx]

; exponent diff
; reads: ymm0, ymm1
; out: ymm2, ymm3, ymm4
	vpand		ymm2,	ymm0,	[zero_sign]	; remove sign
	vpand		ymm3,	ymm1,	[zero_sign]
	vpsrldq		ymm2,	ymm2,	FRAC_BITS/8	; move exp to left (remove frac)
	vpsrldq		ymm3,	ymm3,	FRAC_BITS/8
	vpsubsw		ymm5,	ymm2,	ymm3		; subtract exponents
	vpabsw		ymm5,	ymm5			; absolute value of exp diff
	vpmaxud		ymm2,	ymm2,	ymm3
	vpcmpeqd	ymm2,	ymm2,	ymm3		; compare fractions
	vpblendvb	ymm3,	ymm0,	ymm1,	ymm2	; sort
	vpcmpeqd	ymm15,	ymm15,	ymm15		; 0xFF...FF in ymm15
	vpxor		ymm2,	ymm2,	ymm15		; negate ymm2
	vpblendvb	ymm4,	ymm0,	ymm1,	ymm2
	vmovdqa		ymm2,	ymm5			; save absolute exp diff to ymm2

	; check output; ymm3 and ymm4 should be sorted according to exponent (exp3 > exp4)
	; ymm2 holds exp4-exp3

; extract fractions
; reads: ymm3, ymm4
; out: ymm5, ymm6
	vpand		ymm5,	ymm3,	[zero_expsgn]	; remove exp and sign
	vpand		ymm6,	ymm4,	[zero_expsgn]
	vpor		ymm5,	ymm5,	[hidden_one]	; add hidden one
	vpor		ymm6,	ymm6,	[hidden_one]

	; get sign bit
	vmovdqa		ymm15,	[zero_sign]
	vpcmpeqd	ymm14,	ymm14,	ymm14
	vpxor		ymm15,	ymm15,	ymm14		; ymm15 = sign bit

	; convert to 2C
	vpand		ymm7,	ymm3,	ymm15
	vpand		ymm8,	ymm4,	ymm15
	vpcmpeqq	ymm7,	ymm7,	ymm15
	vpcmpeqq	ymm8,	ymm8,	ymm15
	vpshufd		ymm7,	ymm7,	0xFF		; ymm7 = ones if negative
	vpshufd		ymm8,	ymm8,	0xFF		; ymm8 = ones if negative


; alignment
	vpcmpeqw	ymm7,	ymm7,	ymm7
	vpsrldq		ymm7,	ymm7,	15
	vpsrlq		ymm7,	ymm7,	5		; ymm7 = [0x7; 0x7]

	vpcmpeqd	ymm15,	ymm15,	ymm15
	vpmuldq		ymm8,	ymm2,	ymm15		; negative count


; loop epilog
	add	rsi,	32
	add	rdx,	32
	add	rcx,	32
	sub	rdi,	1
	jnz	.loop
	rep ret


quadruple_sub_avx:
	rep ret


quadruple_mul_avx:
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
	vpadddq		ymm3,	ymm0,	ymm1,	ymm4,	ymm5,	ymm6
	vmovdqa		ymm0,	ymm3
	rep ret

section .data
align 32
	zero_sign: 	dq	0xFFFFFFFFFFFFFFFF, 0x7FFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF, 0x7FFFFFFFFFFFFFFF
	zero_expsgn: 	dq	0xFFFFFFFFFFFFFFFF, 0x0000FFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF, 0x0000FFFFFFFFFFFF
	hidden_one: 	dq	0x0000000000000000, 0x0001000000000000, 0x0000000000000000, 0x0001000000000000
	adddq_sgn_xor:	dq	0x8000000000000000, 0x8000000000000000, 0x8000000000000000, 0x8000000000000000
