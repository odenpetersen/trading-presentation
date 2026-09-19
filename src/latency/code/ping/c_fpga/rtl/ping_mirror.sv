// (C) FPGA: pure hardware ping responder, no host CPU in the loop at
// all. Captures a whole frame into a small buffer (unlike
// ../../fpga/rtl/udp_key_parser.sv's cut-through streaming design --
// here the fields that need rewriting sit BEFORE the fields we'd need to
// have already seen to rewrite them, e.g. dest MAC at byte 0 needs to
// become the src MAC that only arrives at byte 6, so store-and-forward
// is the simplest correct design, not a corner cut), swaps
// src<->dst MAC/IP/UDP-port in place, and streams it straight back out.
//
// No checksum recompute needed: IPv4/UDP checksums are a ones-complement
// sum over the header words, and swapping which of a pair of words is
// "source" and which is "dest" doesn't change that sum -- a checksum
// that covered the original frame still covers the swapped one.
//
// Limitation: single frame in flight, same as tx_response_fsm.sv --
// RX bytes that arrive while a reply is still being sent (state==SEND)
// are silently dropped, not queued.
import ping_pkg::*;

module ping_mirror (
    input  logic                  clk,
    input  logic                  rst,

    input  logic [DATA_WIDTH-1:0] s_axis_tdata,
    input  logic [KEEP_WIDTH-1:0] s_axis_tkeep,
    input  logic                  s_axis_tvalid,
    input  logic                  s_axis_tlast,
    input  logic                  s_axis_tuser,   // MAC RX error flag, meaningful at tlast

    output logic [DATA_WIDTH-1:0] m_axis_tdata,
    output logic [KEEP_WIDTH-1:0] m_axis_tkeep,
    output logic                  m_axis_tvalid,
    output logic                  m_axis_tlast,
    input  logic                  m_axis_tready
);

    logic [7:0] buf_mem [0:FRAME_BUF_BYTES-1];

    localparam int POS_W = $clog2(FRAME_BUF_BYTES);
    logic [POS_W-1:0] byte_pos;
    logic [POS_W-1:0] send_len, send_pos;

    typedef enum logic [0:0] {CAPTURE, SEND} state_t;
    state_t state;

    // Evaluated against whatever's already landed in buf_mem from prior
    // cycles -- safe because every field checked here sits below byte
    // 37, well under the byte_pos>=MIN_HDR_BYTES-1 (41) gate below.
    logic is_ping_frame;
    always_comb begin
        is_ping_frame = (byte_pos >= MIN_HDR_BYTES-1)
                      && !s_axis_tuser
                      && (buf_mem[ETHERTYPE_LO]   == ETHERTYPE_IPV4_HI)
                      && (buf_mem[ETHERTYPE_LO+1] == ETHERTYPE_IPV4_LO)
                      && (buf_mem[IP_PROTO_POS]   == IPPROTO_UDP)
                      && ({buf_mem[UDP_DST_LO], buf_mem[UDP_DST_LO+1]} == PING_UDP_PORT);
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            state    <= CAPTURE;
            byte_pos <= '0;
        end else begin
            case (state)
                CAPTURE: if (s_axis_tvalid) begin
                    if (byte_pos < FRAME_BUF_BYTES) buf_mem[byte_pos] <= s_axis_tdata;
                    if (s_axis_tlast) begin
                        byte_pos <= '0;
                        if (is_ping_frame) begin
                            // Swap pairs in place -- nonblocking assignment
                            // reads both sides' OLD values this same cycle,
                            // so this is a real swap, not a self-clobbering copy.
                            for (int i = 0; i < 6; i++) begin
                                buf_mem[ETH_DST_LO+i] <= buf_mem[ETH_SRC_LO+i];
                                buf_mem[ETH_SRC_LO+i] <= buf_mem[ETH_DST_LO+i];
                            end
                            for (int i = 0; i < 4; i++) begin
                                buf_mem[IP_DST_LO+i] <= buf_mem[IP_SRC_LO+i];
                                buf_mem[IP_SRC_LO+i] <= buf_mem[IP_DST_LO+i];
                            end
                            for (int i = 0; i < 2; i++) begin
                                buf_mem[UDP_DST_LO+i] <= buf_mem[UDP_SRC_LO+i];
                                buf_mem[UDP_SRC_LO+i] <= buf_mem[UDP_DST_LO+i];
                            end
                            send_len <= byte_pos + 1'b1;
                            send_pos <= '0;
                            state    <= SEND;
                        end
                    end else begin
                        byte_pos <= byte_pos + 1'b1;
                    end
                end
                SEND: if (m_axis_tvalid && m_axis_tready) begin
                    if (send_pos + 1'b1 >= send_len) state <= CAPTURE;
                    else                              send_pos <= send_pos + 1'b1;
                end
            endcase
        end
    end

    assign m_axis_tdata  = buf_mem[send_pos];
    assign m_axis_tkeep  = 1'b1;
    assign m_axis_tvalid = (state == SEND);
    assign m_axis_tlast  = (state == SEND) && (send_pos + 1'b1 >= send_len);

endmodule
