CC=gcc
CFLAGS=-Wall -Wextra -mavx2 -g
LFLAGS=-lquadmath

ASM=nasm
AFLAGS=-f elf64

all: quadruple \
	tests/vpadddq \
	tests/vpsrldqy \
	tests/vpslldqy \
	tests/efrac

test: tests/vpadddq tests/vpsrldqy tests/vpslldqy tests/efrac
	@echo "TESTS"
	./tests/vpadddq
	./tests/vpsrldqy
	./tests/vpslldqy
	./tests/efrac

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

clean:
	rm -f *.o
	rm -f tests/*.o
	rm -f quadruple
	rm -f tests/vpadddq
	rm -f tests/vpsrldqy
	rm -f tests/vpslldqy
	rm -f tests/efrac
