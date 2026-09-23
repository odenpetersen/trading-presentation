CLANG = clang
CC = gcc
CFLAGS = -O2 -Wall -Wextra

all: xdp_kern.o xsk_responder

xdp_kern.o: xdp_kern.c
	$(CLANG) -O2 -g -target bpf -c xdp_kern.c -o xdp_kern.o

xsk_responder: xsk_responder.c
	$(CC) $(CFLAGS) -o xsk_responder xsk_responder.c -lxdp -lbpf

clean:
	rm -f xdp_kern.o xsk_responder
