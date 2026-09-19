// Parameters for the tick-to-trade cache-and-respond datapath.
//
// Verified against pcaps/ny4-xnas-tvitch-a-20230822T145000.pcap.zst (NASDAQ
// TotalView-ITCH 5.0 over MoldUDP64): 8.6M packets inspected, 100% VLAN
// (0x8100)-tagged, 100% UDP dest port 26477, IPv4 20B header (no options).
// Byte layout cross-checked against github.com/bbalouki/itch's message
// structs (exact match on OrderDeleteMessage=19B, AddOrderMessage=36B).
//
// Hardware: ALINX AXKU3 (Xilinx Kintex UltraScale+ XCKU3P-2FFVB676I),
// confirmed via JTAG IDCODE + board marking + PCB silkscreen "AX9113".
// Its only Ethernet interface is a built-in 10/100/1000M copper RJ-45 --
// confirmed by the user's cable (RJ45 both ends, no FMC/SFP+ module) -- so
// this targets Xilinx's Tri-Mode Ethernet MAC, whose native AXI4-Stream is
// 8 bits wide (1 byte/cycle @ ~125MHz for 1000BASE-T), not a wide bus.
package market_data_pkg;

    // AXI4-Stream datapath width -- must match your MAC IP's native width.
    // 8 is correct for Xilinx's Tri-Mode Ethernet MAC (1G copper, this
    // board's only interface). At this width the header-through-key (70
    // bytes) takes ~70 cycles to arrive, not 1-2 -- udp_key_parser.sv is a
    // byte-serial parser, not a wide-bus single/dual-beat one. NOTE: at
    // 1Gbps, wire serialization of those 70 bytes alone is ~560ns -- that
    // physically dominates the total latency budget, not our own logic;
    // if you later add a faster interface (e.g. an FMC 10G module), widen
    // this and revisit udp_key_parser.sv's byte-position-based design.
    localparam int DATA_WIDTH   = 8;
    localparam int KEEP_WIDTH   = DATA_WIDTH/8;

    // Header layout: single 802.1Q VLAN tag (always present on this feed),
    // IPv4 with 20B header (IHL=5, no options), UDP.
    localparam int ETH_HDR_BYTES  = 14;
    localparam int VLAN_HDR_BYTES = 4;   // 0x8100 TPID + TCI; feed is always tagged
    localparam int IP_HDR_BYTES   = 20;
    localparam int UDP_HDR_BYTES  = 8;
    localparam int L4_PAYLOAD_OFFSET_BYTES =
        ETH_HDR_BYTES + VLAN_HDR_BYTES + IP_HDR_BYTES + UDP_HDR_BYTES; // 46

    // MoldUDP64 session wrapper: Session[10] + SequenceNumber[8] +
    // MessageCount[2], then repeated {MessageLength[2], MessageData}.
    // NOTE: ~10.3% of packets carry more than one ITCH message
    // (MessageCount > 1, up to 29 seen) -- this design only acts on the
    // FIRST message in a packet; see README known limitations.
    localparam int MOLD_HDR_BYTES     = 20;
    localparam int MSG_LEN_BYTES      = 2;
    localparam int FIRST_MSG_OFFSET_BYTES =
        L4_PAYLOAD_OFFSET_BYTES + MOLD_HDR_BYTES + MSG_LEN_BYTES; // 68 (MessageType byte)

    // EtherType / IP protocol constants for header validation.
    localparam bit [15:0] ETHERTYPE_VLAN = 16'h8100;
    localparam bit [15:0] ETHERTYPE_IPV4 = 16'h0800;
    localparam bit [7:0]  IPPROTO_UDP    = 8'd17;

    // Verified dest UDP port for this feed (ny4-xnas-tvitch-a).
    localparam bit [15:0] MARKET_DATA_UDP_PORT = 16'd26477;

    // Cache key = StockLocate: 2 bytes, at relative offset 1 within EVERY
    // ITCH 5.0 message (right after the 1-byte MessageType) -- confirmed
    // universal across message types by both the NASDAQ spec's common
    // header description and the reference parser's message structs.
    // Offset is relative to L4_PAYLOAD_OFFSET_BYTES (MoldUDP64 start),
    // matching udp_key_parser.sv's addressing convention.
    localparam int KEY_OFFSET_BYTES = FIRST_MSG_OFFSET_BYTES - L4_PAYLOAD_OFFSET_BYTES + 1; // 23
    localparam int KEY_WIDTH_BYTES  = 2;
    localparam int KEY_WIDTH_BITS   = KEY_WIDTH_BYTES*8;

    // Cache sizing. If instrument IDs are dense (0..N-1) address directly;
    // if sparse, hash KEY down to CACHE_ADDR_WIDTH bits before indexing
    // (see udp_key_parser.sv).
    localparam int CACHE_ADDR_WIDTH = 12;              // 4096 lines
    localparam int CACHE_DEPTH      = 1 << CACHE_ADDR_WIDTH;

    // Max stored response frame size (bytes), rounded up to a beat boundary.
    localparam int MAX_FRAME_BYTES  = 256;
    localparam int MAX_FRAME_BEATS  = (MAX_FRAME_BYTES + KEEP_WIDTH - 1) / KEEP_WIDTH;

    // Cache line layout as seen through the AXI BRAM Controller (Port A):
    //   [0]                     : valid (1 = line holds a live response)
    //   [1 +: 16]               : frame length in bytes
    //   [17 +: MAX_FRAME_BYTES] : frame bytes, byte 0 first
    localparam int LINE_VALID_BIT    = 0;
    localparam int LINE_LEN_LSB      = 1;
    localparam int LINE_LEN_WIDTH    = 16;
    localparam int LINE_DATA_LSB     = LINE_LEN_LSB + LINE_LEN_WIDTH;
    localparam int LINE_WIDTH_BITS   = LINE_DATA_LSB + MAX_FRAME_BYTES*8;

    typedef struct packed {
        logic                       valid;
        logic [15:0]                len_bytes;
        logic [MAX_FRAME_BYTES*8-1:0] frame;
    } cache_line_t;

endpackage
