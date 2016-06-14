CC=gcc
CFLAGS=-Wall -Wextra -mavx2 -g
LFLAGS=-lquadmath

ASM=nasm
AFLAGS=-f elf64

all: quadruple \
	tests/vpadddq \
	tests/vpsrldqy \
	tests/vpslldqy \
	tests/efrac \
	tests/normalize \
	tests/add	\
	tests/mul

test: tests/vpadddq tests/vpsrldqy tests/vpslldqy tests/efrac tests/normalize tests/add tests/mul
	@echo "TESTS"
	./tests/vpadddq
	./tests/vpsrldqy
	./tests/vpslldqy
	./tests/efrac
	./tests/normalize
	./tests/add
	./tests/mul

check: quadruple
	@echo "CHECK"
	./quadruple add 1000000 1 avx_checked | grep "relative"
	./quadruple sub 1000000 1 avx_checked | grep "relative"
	./quadruple mul 1000000 1 avx_checked | grep "relative"

perftest: quadruple
	@echo "PERFTEST"
	@echo "ADD"
	./quadruple add 256 2000000 avx | grep "Calculation"
	./quadruple add 256 2000000 gcc | grep "Calculation"
	@echo "SUB"
	./quadruple sub 256 2000000 avx | grep "Calculation"
	./quadruple sub 256 2000000 gcc | grep "Calculation"
	@echo "MUL"
	./quadruple mul 256 2000000 avx | grep "Calculation"
	./quadruple mul 256 2000000 gcc | grep "Calculation"

main.o: main.c
	$(CC) $(CFLAGS) -c main.c

quadruple.o: quadruple.s
	$(ASM) $(AFLAGS) quadruple.s

quadruple: main.o quadruple.o
	$(CC) $(CFLAGS) main.o quadruple.o ${LFLAGS} -o quadruple

tests/vpadddq.o: tests/vpadddq.c
	$(CC) $(CFLAGS) -c tests/vpadddq.c -o tests/vpadddq.o

tests/vpadddq: tests/vpadddq.o quadruple.o
	$(CC) $(CFLAGS) tests/vpadddq.o quadruple.o ${LFLAGS} -o tests/vpadddq

tests/vpsrldqy.o: tests/vpsrldqy.c
	$(CC) $(CFLAGS) -c tests/vpsrldqy.c -o tests/vpsrldqy.o

tests/vpsrldqy: tests/vpsrldqy.o quadruple.o
	$(CC) $(CFLAGS) tests/vpsrldqy.o quadruple.o ${LFLAGS} -o tests/vpsrldqy

tests/vpslldqy.o: tests/vpslldqy.c
	$(CC) $(CFLAGS) -c tests/vpslldqy.c -o tests/vpslldqy.o

tests/vpslldqy: tests/vpslldqy.o quadruple.o
	$(CC) $(CFLAGS) tests/vpslldqy.o quadruple.o ${LFLAGS} -o tests/vpslldqy

tests/efrac.o: tests/efrac.c
	$(CC) $(CFLAGS) -c tests/efrac.c -o tests/efrac.o

tests/efrac: tests/efrac.o quadruple.o
	$(CC) $(CFLAGS) tests/efrac.o quadruple.o ${LFLAGS} -o tests/efrac

tests/normalize.o: tests/normalize.c
	$(CC) $(CFLAGS) -c tests/normalize.c -o tests/normalize.o

tests/normalize: tests/normalize.o quadruple.o
	$(CC) $(CFLAGS) tests/normalize.o quadruple.o ${LFLAGS} -o tests/normalize

tests/add.o: tests/add.c
	$(CC) $(CFLAGS) -c tests/add.c -o tests/add.o

tests/add: tests/add.o quadruple.o
	$(CC) $(CFLAGS) tests/add.o quadruple.o ${LFLAGS} -o tests/add

tests/mul.o: tests/mul.c
	$(CC) $(CFLAGS) -c tests/mul.c -o tests/mul.o

tests/mul: tests/mul.o quadruple.o
	$(CC) $(CFLAGS) tests/mul.o quadruple.o ${LFLAGS} -o tests/mul

clean:
	rm -f *.o
	rm -f tests/*.o
	rm -f quadruple
	rm -f tests/vpadddq
	rm -f tests/vpsrldqy
	rm -f tests/vpslldqy
	rm -f tests/efrac
	rm -f tests/normalize
	rm -f tests/add
	rm -f tests/mul
