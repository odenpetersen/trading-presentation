// (B) kernel bypass: takes the NIC over from the kernel entirely (DPDK
// PMD, not AF_XDP) and polls it directly in userspace. Since the kernel
// no longer owns the interface once bound to a DPDK-compatible driver,
// this app also has to answer ARP for its own IP itself -- otherwise the
// peer machine can never resolve a MAC to send pings to in the first
// place.
//
// Ping replies are a byte-for-byte mirror: swap src/dst MAC, src/dst IP,
// src/dst UDP port, retransmit the same mbuf. No checksum recompute --
// IPv4/UDP checksums are a ones-complement sum over the header words, and
// swapping which of two words is "source" and which is "dest" doesn't
// change that sum, so a stored checksum stays valid across the swap.
#include <stdio.h>
#include <string.h>
#include <signal.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <rte_eal.h>
#include <rte_ethdev.h>
#include <rte_mbuf.h>
#include <rte_ether.h>
#include <rte_ip.h>
#include <rte_udp.h>
#include <rte_arp.h>
#include "../common/ping_proto.h"

#define NUM_MBUFS 8191
#define MBUF_CACHE_SIZE 250
#define BURST_SIZE 32

static uint16_t port_id;
static struct rte_ether_addr my_mac;
static uint32_t my_ip; // network byte order

static volatile sig_atomic_t running = 1;
static void on_sigint(int sig) { (void)sig; running = 0; }

static int port_init(uint16_t port, struct rte_mempool *pool) {
	struct rte_eth_conf conf = {0};
	if (rte_eth_dev_configure(port, 1, 1, &conf) < 0) return -1;
	if (rte_eth_rx_queue_setup(port, 0, 1024, rte_eth_dev_socket_id(port), NULL, pool) < 0) return -1;
	if (rte_eth_tx_queue_setup(port, 0, 1024, rte_eth_dev_socket_id(port), NULL) < 0) return -1;
	if (rte_eth_dev_start(port) < 0) return -1;
	rte_eth_promiscuous_enable(port);
	rte_eth_macaddr_get(port, &my_mac);
	return 0;
}

static int handle_arp(struct rte_mbuf *m, struct rte_ether_hdr *eth) {
	struct rte_arp_hdr *arp = (struct rte_arp_hdr*)(eth + 1);
	if (rte_be_to_cpu_16(arp->arp_opcode) != RTE_ARP_OP_REQUEST || arp->arp_data.arp_tip != my_ip) return 0;
	eth->dst_addr = eth->src_addr;
	eth->src_addr = my_mac;
	arp->arp_opcode = rte_cpu_to_be_16(RTE_ARP_OP_REPLY);
	arp->arp_data.arp_tha = arp->arp_data.arp_sha;
	arp->arp_data.arp_tip = arp->arp_data.arp_sip;
	arp->arp_data.arp_sha = my_mac;
	arp->arp_data.arp_sip = my_ip;
	return rte_eth_tx_burst(port_id, 0, &m, 1);
}

static int handle_ping(struct rte_mbuf *m, struct rte_ether_hdr *eth, struct rte_ipv4_hdr *ip) {
	struct rte_udp_hdr *udp = (struct rte_udp_hdr*)((uint8_t*)ip + sizeof *ip); // no IP options on this wire
	if (rte_be_to_cpu_16(udp->dst_port) != PING_PORT) return 0;
	struct rte_ether_addr tmp_mac = eth->dst_addr;
	eth->dst_addr = eth->src_addr; eth->src_addr = tmp_mac;
	uint32_t tmp_ip = ip->src_addr; ip->src_addr = ip->dst_addr; ip->dst_addr = tmp_ip;
	uint16_t tmp_port = udp->src_port; udp->src_port = udp->dst_port; udp->dst_port = tmp_port;
	return rte_eth_tx_burst(port_id, 0, &m, 1);
}

int main(int argc, char **argv) {
	int consumed = rte_eal_init(argc, argv);
	if (consumed < 0) rte_exit(EXIT_FAILURE, "EAL init failed\n");
	argc -= consumed; argv += consumed;
	if (argc < 2) rte_exit(EXIT_FAILURE, "usage: %s [EAL args --] <my_ip>\n", argv[0]);
	struct in_addr a;
	if (inet_pton(AF_INET, argv[1], &a) != 1) rte_exit(EXIT_FAILURE, "bad ip %s\n", argv[1]);
	my_ip = a.s_addr;

	if (rte_eth_dev_count_avail() == 0) rte_exit(EXIT_FAILURE, "no DPDK-bound ports found -- run setup.sh first\n");
	RTE_ETH_FOREACH_DEV(port_id) break; // first available port

	struct rte_mempool *pool = rte_pktmbuf_pool_create("ping_pool", NUM_MBUFS, MBUF_CACHE_SIZE, 0, RTE_MBUF_DEFAULT_BUF_SIZE, rte_socket_id());
	if (!pool) rte_exit(EXIT_FAILURE, "mbuf pool alloc failed\n");
	if (port_init(port_id, pool) < 0) rte_exit(EXIT_FAILURE, "port init failed\n");

	char macstr[RTE_ETHER_ADDR_FMT_SIZE];
	rte_ether_format_addr(macstr, sizeof macstr, &my_mac);
	printf("DPDK ping responder up: port=%u mac=%s ip=%s\n", port_id, macstr, argv[1]);

	signal(SIGINT, on_sigint);
	while (running) {
		struct rte_mbuf *bufs[BURST_SIZE];
		uint16_t n = rte_eth_rx_burst(port_id, 0, bufs, BURST_SIZE);
		for (uint16_t i = 0; i < n; ++i) {
			struct rte_mbuf *m = bufs[i];
			struct rte_ether_hdr *eth = rte_pktmbuf_mtod(m, struct rte_ether_hdr*);
			uint16_t ethertype = rte_be_to_cpu_16(eth->ether_type);
			int sent = 0;
			if (ethertype == RTE_ETHER_TYPE_ARP) {
				sent = handle_arp(m, eth);
			} else if (ethertype == RTE_ETHER_TYPE_IPV4) {
				struct rte_ipv4_hdr *ip = (struct rte_ipv4_hdr*)(eth + 1);
				if (ip->next_proto_id == IPPROTO_UDP) sent = handle_ping(m, eth, ip);
			}
			if (!sent) rte_pktmbuf_free(m);
		}
	}
	rte_eth_dev_stop(port_id);
	return 0;
}
