CC=gcc
CFLAGS=-Wall -Wextra -mavx2 -g
LFLAGS=-lquadmath

ASM=nasm
AFLAGS=-f elf64

all: quadruple \
	tests/vpadddq

test: tests/vpadddq
	@echo "TESTS"
	./tests/vpadddq

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

clean:
	rm -f *.o
	rm -f tests/*.o
	rm -f quadruple
	rm -f tests/vpadddq
