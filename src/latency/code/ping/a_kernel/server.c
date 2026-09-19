// (A) kernel networking stack: plain UDP socket, recvfrom/sendto through
// the normal IP stack. Echoes whatever payload arrives, unchanged.
#include <stdio.h>
#include <string.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <unistd.h>
#include "../common/ping_proto.h"

int main() {
	int fd = socket(AF_INET, SOCK_DGRAM, 0);
	struct sockaddr_in addr = {.sin_family = AF_INET, .sin_addr.s_addr = INADDR_ANY, .sin_port = htons(PING_PORT)};
	bind(fd, (struct sockaddr*)&addr, sizeof addr);
	printf("kernel-stack ping responder on :%d\n", PING_PORT);
	char buf[1500];
	for (;;) {
		struct sockaddr_in from;
		socklen_t fromlen = sizeof from;
		ssize_t n = recvfrom(fd, buf, sizeof buf, 0, (struct sockaddr*)&from, &fromlen);
		if (n < 0) continue;
		sendto(fd, buf, n, 0, (struct sockaddr*)&from, fromlen);
	}
}
