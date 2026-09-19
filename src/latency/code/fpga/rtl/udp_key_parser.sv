// Byte-serial header parser for a 1-byte/cycle (KEEP_WIDTH=1) RX
// AXI4-Stream, matching Xilinx's Tri-Mode Ethernet MAC (1G copper -- the
// AXKU3's only interface). Tracks how many bytes into the current frame
// we are and, for each field of interest, shift-accumulates its bytes as
// they pass. Big-endian fields assemble correctly for free: shifting a
// new byte into the low end of an accumulator, MSB-first, is exactly
// network byte order -- no explicit byte-order bookkeeping needed (unlike
// the wide-bus version, which had to get this right by hand and initially
// didn't).
import market_data_pkg::*;

module udp_key_parser (
    input  logic                        clk,
    input  logic                        rst,

    input  logic [DATA_WIDTH-1:0]       s_axis_tdata,
    input  logic [KEEP_WIDTH-1:0]       s_axis_tkeep,
    input  logic                        s_axis_tvalid,
    input  logic                        s_axis_tlast,
    input  logic                        s_axis_tuser,   // MAC RX error flag (only meaningful at tlast)

    output logic                        lookup_valid,   // 1-cycle pulse
    output logic [CACHE_ADDR_WIDTH-1:0] lookup_addr
);

    // Byte offsets of interest within the frame (byte 0 = first byte of
    // dest MAC). Derived from market_data_pkg's verified layout.
    localparam int OUTER_ET_LO  = 12;
    localparam int OUTER_ET_HI  = 13;
    localparam int INNER_ET_LO  = 16;
    localparam int INNER_ET_HI  = 17;
    localparam int IP_PROTO_POS = ETH_HDR_BYTES + VLAN_HDR_BYTES + 9;                         // 37
    localparam int UDP_PORT_LO  = ETH_HDR_BYTES + VLAN_HDR_BYTES + IP_HDR_BYTES + 2;           // 40
    localparam int UDP_PORT_HI  = UDP_PORT_LO + 1;                                             // 41
    localparam int KEY_LO       = L4_PAYLOAD_OFFSET_BYTES + KEY_OFFSET_BYTES;                  // 69
    localparam int KEY_HI       = KEY_LO + KEY_WIDTH_BYTES - 1;                                // 70

    // Position of the CURRENT incoming byte within its frame (0-based).
    logic [15:0] byte_pos;
    always_ff @(posedge clk) begin
        if (rst) begin
            byte_pos <= 16'd0;
        end else if (s_axis_tvalid) begin
            byte_pos <= s_axis_tlast ? 16'd0 : (byte_pos + 16'd1);
        end
    end

    logic [15:0] outer_ethertype, inner_ethertype, udp_dst_port;
    logic [7:0]  ip_proto;
    logic [KEY_WIDTH_BITS-1:0] key;

    always_ff @(posedge clk) begin
        if (s_axis_tvalid) begin
            if (byte_pos inside {[OUTER_ET_LO:OUTER_ET_HI]})
                outer_ethertype <= {outer_ethertype[7:0], s_axis_tdata};
            if (byte_pos inside {[INNER_ET_LO:INNER_ET_HI]})
                inner_ethertype <= {inner_ethertype[7:0], s_axis_tdata};
            if (byte_pos == IP_PROTO_POS)
                ip_proto <= s_axis_tdata;
            if (byte_pos inside {[UDP_PORT_LO:UDP_PORT_HI]})
                udp_dst_port <= {udp_dst_port[7:0], s_axis_tdata};
            if (byte_pos inside {[KEY_LO:KEY_HI]})
                key <= {key[KEY_WIDTH_BITS-9:0], s_axis_tdata};
        end
    end

    // Pulses the cycle after the last key byte (byte_pos==KEY_HI) is
    // processed -- by then `key` has just been updated (same clock edge)
    // to include it, so reading it here is already correct, no extra
    // delay needed. All other fields close their windows well before
    // byte 70, so they're long stable by the time this fires.
    //
    // NOTE on cut-through / FCS: this fires before the frame (and its
    // trailing FCS check) has finished arriving, by design -- that's the
    // whole point of not waiting for the full packet. It means a frame
    // that fails its Ethernet FCS check late in the packet can still
    // trigger a response before that's known; genuine cut-through
    // switches have this exact same tradeoff. Not mitigated here.
    logic key_done;
    always_ff @(posedge clk) begin
        if (rst) key_done <= 1'b0;
        else     key_done <= s_axis_tvalid && (byte_pos == KEY_HI);
    end

    logic is_market_data;
    always_comb begin
        is_market_data = (outer_ethertype == ETHERTYPE_VLAN)
                       && (inner_ethertype == ETHERTYPE_IPV4)
                       && (ip_proto  == IPPROTO_UDP)
                       && (MARKET_DATA_UDP_PORT == 16'd0 || udp_dst_port == MARKET_DATA_UDP_PORT);
    end

    assign lookup_valid = key_done && is_market_data;
    assign lookup_addr  = key[CACHE_ADDR_WIDTH-1:0];

endmodule
