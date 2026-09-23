// (B) kernel bypass, take two: AF_XDP instead of DPDK. Unlike DPDK this
// doesn't take the NIC away from the kernel -- this eBPF program runs in
// the driver's RX path and redirects ONLY packets matching our ping port
// into an AF_XDP socket; everything else (SSH included) falls through to
// XDP_PASS and the normal kernel stack, untouched. That's the whole
// point: no NIC unbind, no dropped SSH session, safe to run on enp5s0.
#include <linux/bpf.h>
#include <linux/if_ether.h>
#include <linux/in.h>
#include <linux/ip.h>
#include <linux/udp.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_endian.h>

#define PING_PORT 9876

struct {
	__uint(type, BPF_MAP_TYPE_XSKMAP);
	__uint(max_entries, 64);
	__uint(key_size, sizeof(int));
	__uint(value_size, sizeof(int));
} xsks_map SEC(".maps");

SEC("xdp")
int xdp_ping_redirect(struct xdp_md *ctx) {
	void *data = (void *)(long)ctx->data;
	void *data_end = (void *)(long)ctx->data_end;

	struct ethhdr *eth = data;
	if ((void *)(eth + 1) > data_end) return XDP_PASS;
	if (eth->h_proto != bpf_htons(ETH_P_IP)) return XDP_PASS;

	struct iphdr *ip = (void *)(eth + 1);
	if ((void *)(ip + 1) > data_end) return XDP_PASS;
	if (ip->protocol != IPPROTO_UDP) return XDP_PASS;

	struct udphdr *udp = (void *)ip + ip->ihl * 4; // no IP options on this wire
	if ((void *)(udp + 1) > data_end) return XDP_PASS;
	if (udp->dest != bpf_htons(PING_PORT)) return XDP_PASS;

	// Falls back to XDP_PASS if no AF_XDP socket is registered for this
	// RX queue yet (xsk_responder not running) -- never a black hole.
	return bpf_redirect_map(&xsks_map, ctx->rx_queue_index, XDP_PASS);
}

char _license[] SEC("license") = "GPL";
