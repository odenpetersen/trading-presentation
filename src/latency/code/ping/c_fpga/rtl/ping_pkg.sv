// Parameters for the FPGA ping responder: byte-serial mirror on a 1G
// Tri-Mode Ethernet MAC (same 8-bit AXI4-Stream width as
// ../../fpga/rtl/market_data_pkg.sv, same board/MAC -- see that file's
// header for why 8 bits, not a wide bus).
//
// Untagged Ethernet, IPv4 (20B header, no options), UDP: the standard
// case for two boxes on a plain switched LAN, unlike the exchange feed
// in market_data_pkg.sv which is always 802.1Q-tagged. If your LAN
// tags traffic, add the same 4-byte VLAN offset that file uses.
package ping_pkg;

    localparam int DATA_WIDTH = 8;
    localparam int KEEP_WIDTH = 1;

    localparam int ETH_HDR_BYTES = 14;
    localparam int IP_HDR_BYTES  = 20;
    localparam int UDP_HDR_BYTES = 8;
    localparam int MIN_HDR_BYTES = ETH_HDR_BYTES + IP_HDR_BYTES + UDP_HDR_BYTES; // 42

    localparam bit [7:0]  ETHERTYPE_IPV4_HI = 8'h08; // ethertype 0x0800, big-endian on the wire
    localparam bit [7:0]  ETHERTYPE_IPV4_LO = 8'h00;
    localparam bit [7:0]  IPPROTO_UDP       = 8'd17;
    localparam bit [15:0] PING_UDP_PORT     = 16'd9876; // matches ../common/ping_proto.h PING_PORT

    // Byte offsets into the frame, 0 = first byte of the dest MAC.
    localparam int ETH_DST_LO  = 0,  ETH_SRC_LO  = 6;
    localparam int ETHERTYPE_LO = 12;
    localparam int IP_PROTO_POS = 23;
    localparam int IP_SRC_LO   = 26, IP_DST_LO   = 30;
    localparam int UDP_SRC_LO  = 34, UDP_DST_LO  = 36;

    // Whole-frame capture buffer. Our ping_pkt payload is 16B, so the
    // real frame is 14+20+8+16=58B -- 128 leaves headroom for NIC padding
    // up to the 60B Ethernet minimum and then some.
    localparam int FRAME_BUF_BYTES = 128;

endpackage
