#pragma once
#include <stdint.h>

// Same wire format used by all three responder implementations (kernel
// stack, DPDK, FPGA) so RTTs are directly comparable: a UDP packet to
// PING_PORT carrying this payload, echoed back byte-for-byte unchanged.
// The FPGA doesn't parse this struct at all -- it just mirrors whatever
// UDP payload arrives on PING_PORT -- so client-side RTT math must only
// ever depend on send_ns, never on the responder having touched it.

#define PING_PORT 9876
#define PING_MAGIC 0x31474e50u // "PNG1", LE on the wire

#pragma pack(push,1)
struct ping_pkt { uint32_t magic; uint32_t seq; uint64_t send_ns; };
#pragma pack(pop)
