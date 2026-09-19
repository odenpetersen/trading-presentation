CC = gcc
PKGCONF = pkg-config
CFLAGS = -O2 -Wall -Wextra $(shell $(PKGCONF) --cflags libdpdk)
LDLIBS = $(shell $(PKGCONF) --libs libdpdk)

ping_responder: ping_responder.c ../common/ping_proto.h
	$(CC) $(CFLAGS) -o ping_responder ping_responder.c $(LDLIBS)

clean:
	rm -f ping_responder
