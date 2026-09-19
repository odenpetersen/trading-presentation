CC = gcc
CFLAGS = -O2 -Wall -Wextra

all: server.out client.out

server.out: server.c ../common/ping_proto.h
	$(CC) $(CFLAGS) -o server.out server.c

client.out: client.c ../common/ping_proto.h
	$(CC) $(CFLAGS) -o client.out client.c

clean:
	rm -f server.out client.out
