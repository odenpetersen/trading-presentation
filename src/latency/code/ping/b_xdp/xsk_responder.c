// Userspace half of the AF_XDP responder: loads+attaches xdp_kern.o,
// registers an AF_XDP socket for one RX queue, and echoes back whatever
// ping_pkt-carrying frames the BPF program redirects to it -- same
// swap-in-place, no-checksum-recompute trick as b_dpdk/ping_responder.c
// (see that file's header for why the swap alone is checksum-safe).
// Everything that ISN'T our ping traffic never reaches this process at
// all -- xdp_kern.c falls through to XDP_PASS for it, so the kernel
// keeps routing/serving it (SSH included) exactly as if this weren't
// running.
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <unistd.h>
#include <poll.h>
#include <net/if.h>
#include <sys/socket.h>
#include <linux/if_ether.h>
#include <linux/ip.h>
#include <linux/udp.h>
#include <bpf/bpf.h>
#include <bpf/libbpf.h>
#include <xdp/libxdp.h>
#include <xdp/xsk.h>

#define PING_PORT 9876
#define NUM_FRAMES 64
#define FRAME_SIZE XSK_UMEM__DEFAULT_FRAME_SIZE

static volatile sig_atomic_t running = 1;
static void on_sigint(int sig) { (void)sig; running = 0; }

static void swap_ping(void *pkt) {
	struct ethhdr *eth = pkt;
	struct iphdr *ip = (void *)(eth + 1);
	struct udphdr *udp = (void *)ip + ip->ihl * 4;
	unsigned char tmp_mac[ETH_ALEN];
	memcpy(tmp_mac, eth->h_dest, ETH_ALEN);
	memcpy(eth->h_dest, eth->h_source, ETH_ALEN);
	memcpy(eth->h_source, tmp_mac, ETH_ALEN);
	uint32_t tmp_ip = ip->saddr; ip->saddr = ip->daddr; ip->daddr = tmp_ip;
	uint16_t tmp_port = udp->source; udp->source = udp->dest; udp->dest = tmp_port;
	// checksums untouched -- swapping src/dst leaves the ones-complement sum invariant
}

int main(int argc, char **argv) {
	if (argc < 2) { fprintf(stderr, "usage: %s <ifname> [queue_id]\n", argv[0]); return 1; }
	const char *ifname = argv[1];
	uint32_t queue_id = argc > 2 ? atoi(argv[2]) : 0;
	int ifindex = if_nametoindex(ifname);
	if (!ifindex) { perror("if_nametoindex"); return 1; }

	struct xdp_program *prog = xdp_program__open_file("xdp_kern.o", NULL, NULL);
	if (!prog || libxdp_get_error(prog)) { fprintf(stderr, "failed to open xdp_kern.o\n"); return 1; }

	// Generic/SKB mode only, deliberately -- this hooks in the core
	// networking stack rather than handing the driver's RX/TX ring
	// config to us, so it can't destabilize the NIC the way native mode
	// can on some driver/hardware combos (native mode briefly took the
	// igb driver on this exact box down hard enough to kill the SSH
	// session it was also serving -- recovered only by a reboot). Slower
	// than native, but this demo cares about "skip the socket path", not
	// squeezing out the last few hundred nanoseconds.
	int err = xdp_program__attach(prog, ifindex, XDP_MODE_SKB, 0);
	if (err) { fprintf(stderr, "attach failed: %d\n", err); return 1; }

	// From here on, any early exit must detach `prog` first -- otherwise
	// this leaves an orphaned XDP program on the interface with no
	// process left to clean it up (bit us once already: `ip link set dev
	// enp5s0 xdp off` was needed to clear it by hand).
	struct bpf_object *bpf_obj = xdp_program__bpf_obj(prog);
	struct bpf_map *xsks_map = bpf_object__find_map_by_name(bpf_obj, "xsks_map");
	if (!xsks_map) { fprintf(stderr, "xsks_map not found\n"); goto detach_and_exit; }
	int xsks_map_fd = bpf_map__fd(xsks_map);

	void *umem_area;
	if (posix_memalign(&umem_area, getpagesize(), NUM_FRAMES * FRAME_SIZE)) { perror("posix_memalign"); goto detach_and_exit; }

	struct xsk_umem *umem;
	struct xsk_ring_prod fill;
	struct xsk_ring_cons comp;
	struct xsk_umem_config umem_cfg = {
		.fill_size = XSK_RING_PROD__DEFAULT_NUM_DESCS, .comp_size = XSK_RING_CONS__DEFAULT_NUM_DESCS,
		.frame_size = FRAME_SIZE, .frame_headroom = 0, .flags = 0,
	};
	if (xsk_umem__create(&umem, umem_area, NUM_FRAMES * FRAME_SIZE, &fill, &comp, &umem_cfg)) {
		perror("xsk_umem__create"); goto detach_and_exit;
	}

	struct xsk_ring_cons rx;
	struct xsk_ring_prod tx;
	struct xsk_socket_config xsk_cfg = {
		.rx_size = XSK_RING_CONS__DEFAULT_NUM_DESCS, .tx_size = XSK_RING_PROD__DEFAULT_NUM_DESCS,
		.xdp_flags = 0, .bind_flags = 0,
		// We already loaded+attached our own program above -- tell
		// xsk_socket__create not to also try attaching a default one of
		// its own, which conflicted with ours ("Active program does not
		// match expected" / "Device or resource busy").
		.libxdp_flags = XSK_LIBXDP_FLAGS__INHIBIT_PROG_LOAD,
	};
	struct xsk_socket *xsk;
	if (xsk_socket__create(&xsk, ifname, queue_id, umem, &rx, &tx, &xsk_cfg)) {
		perror("xsk_socket__create"); goto detach_and_exit;
	}
	int sock_fd = xsk_socket__fd(xsk);
	if (bpf_map_update_elem(xsks_map_fd, &queue_id, &sock_fd, 0)) { perror("bpf_map_update_elem"); goto detach_and_exit; }

	// Seed the fill ring with every frame so the kernel has somewhere to
	// land RX packets immediately.
	uint32_t idx;
	size_t reserved = xsk_ring_prod__reserve(&fill, NUM_FRAMES, &idx);
	for (size_t i = 0; i < reserved; i++)
		*xsk_ring_prod__fill_addr(&fill, idx + i) = i * FRAME_SIZE;
	xsk_ring_prod__submit(&fill, reserved);

	printf("AF_XDP ping responder up on %s queue %u -- redirecting UDP:%d only, everything else stays on the kernel path\n",
	       ifname, queue_id, PING_PORT);

	signal(SIGINT, on_sigint);
	struct pollfd pfd = { .fd = sock_fd, .events = POLLIN };
	while (running) {
		poll(&pfd, 1, 1000);

		uint32_t rx_idx;
		size_t n = xsk_ring_cons__peek(&rx, XSK_RING_CONS__DEFAULT_NUM_DESCS, &rx_idx);
		if (!n) continue;

		uint32_t tx_idx = 0;
		size_t reserved_tx = xsk_ring_prod__reserve(&tx, n, &tx_idx);
		size_t sent = 0;
		for (size_t i = 0; i < n; i++) {
			const struct xdp_desc *rxd = xsk_ring_cons__rx_desc(&rx, rx_idx + i);
			uint64_t addr = rxd->addr;
			uint32_t len = rxd->len;
			swap_ping(xsk_umem__get_data(umem_area, addr));
			if (i < reserved_tx) {
				struct xdp_desc *txd = xsk_ring_prod__tx_desc(&tx, tx_idx + i);
				txd->addr = addr;
				txd->len = len;
				sent++;
			}
		}
		xsk_ring_prod__submit(&tx, sent);
		xsk_ring_cons__release(&rx, n);
		if (sent) sendto(sock_fd, NULL, 0, MSG_DONTWAIT, NULL, 0);

		// Recycle completed TX buffers back into the fill ring.
		uint32_t comp_idx;
		size_t completed = xsk_ring_cons__peek(&comp, XSK_RING_CONS__DEFAULT_NUM_DESCS, &comp_idx);
		if (completed) {
			uint32_t fill_idx;
			size_t got = xsk_ring_prod__reserve(&fill, completed, &fill_idx);
			for (size_t i = 0; i < got; i++)
				*xsk_ring_prod__fill_addr(&fill, fill_idx + i) = *xsk_ring_cons__comp_addr(&comp, comp_idx + i);
			xsk_ring_prod__submit(&fill, got);
			xsk_ring_cons__release(&comp, completed);
		}
	}

	xsk_socket__delete(xsk);
	xsk_umem__delete(umem);
	xdp_program__detach(prog, ifindex, XDP_MODE_SKB, 0);
	xdp_program__close(prog);
	return 0;

detach_and_exit:
	xdp_program__detach(prog, ifindex, XDP_MODE_SKB, 0);
	xdp_program__close(prog);
	return 1;
}
