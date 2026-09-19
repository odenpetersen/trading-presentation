// (A) kernel networking stack: sends ping_pkt over UDP, waits for the
// echo, reports RTT. Same output shape as b_dpdk/client mode so the two
// are diffable side by side.
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <unistd.h>
#include "../common/ping_proto.h"

static uint64_t now_ns() {
	struct timespec ts;
	clock_gettime(CLOCK_REALTIME, &ts);
	return (uint64_t)ts.tv_sec * 1000000000ull + ts.tv_nsec;
}

int main(int argc, char **argv) {
	if (argc < 2) { fprintf(stderr, "usage: %s <responder_ip> [count]\n", argv[0]); return 1; }
	int count = argc > 2 ? atoi(argv[2]) : 10;

	int fd = socket(AF_INET, SOCK_DGRAM, 0);
	struct timeval tmo = {.tv_sec = 1};
	setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tmo, sizeof tmo);
	struct sockaddr_in dst = {.sin_family = AF_INET, .sin_port = htons(PING_PORT)};
	inet_pton(AF_INET, argv[1], &dst.sin_addr);

	double sum = 0, min = 1e18, max = 0;
	int received = 0;
	for (int seq = 0; seq < count; ++seq) {
		struct ping_pkt pkt = {.magic = PING_MAGIC, .seq = (uint32_t)seq, .send_ns = now_ns()};
		sendto(fd, &pkt, sizeof pkt, 0, (struct sockaddr*)&dst, sizeof dst);

		struct ping_pkt reply;
		ssize_t n = recvfrom(fd, &reply, sizeof reply, 0, NULL, NULL);
		if (n != sizeof reply || reply.magic != PING_MAGIC) { printf("seq=%d timeout/bad reply\n", seq); continue; }

		double rtt_us = (now_ns() - reply.send_ns) / 1000.0;
		printf("seq=%d rtt=%.1fus\n", seq, rtt_us);
		sum += rtt_us; if (rtt_us < min) min = rtt_us; if (rtt_us > max) max = rtt_us;
		++received;
		usleep(100000);
	}
	if (received) printf("-- %d/%d received, rtt min/avg/max = %.1f/%.1f/%.1fus --\n", received, count, min, sum / received, max);
}
