// Minimal bring-up module: counts completed RX frames and records the
// last frame's length, exposed to the host through the same native-BRAM
// Port A convention as td_cache_bram.sv (wire directly to an AXI BRAM
// Controller). This is the whole "ping software when a packet arrives"
// mechanism for the MVP -- software polls REG_COUNT and notices it change.
//
// Port A (host/PCIe clock domain) and the RX side (MAC clock domain, e.g.
// 125MHz for GMII) are different clocks. The frame counter crosses
// domains via a standard Gray-code + 2-flop synchronizer (safe for a
// monotonically-incrementing counter: exactly one bit changes at a time,
// so a synchronized sample is always either the old or new value, never
// garbage). last_frame_len is a plain register latched at the same
// instant, NOT independently synchronized -- see the note below.
import market_data_pkg::*;

module rx_packet_counter #(
    parameter int REG_ADDR_WIDTH = 4   // 16 words of register space
) (
    // Port A -- AXI BRAM Controller side (host reads)
    input  logic                        clka,
    input  logic                        rsta,
    input  logic                        ena,
    input  logic [3:0]                  wea,     // byte write-enables, unused (read-only regs) but present for axi_bram_ctrl compatibility
    input  logic [REG_ADDR_WIDTH-1:0]   addra,
    input  logic [31:0]                 dina,
    output logic [31:0]                 douta,

    // RX side -- MAC clock domain
    input  logic                        clk_rx,
    input  logic                        rst_rx,
    input  logic                        s_axis_tvalid,
    input  logic                        s_axis_tlast
);

    localparam int REG_COUNT      = 0;
    localparam int REG_LAST_LEN   = 1;

    // --- RX domain: count frames, track current frame's byte length ---
    logic [15:0] rx_count;
    logic [15:0] rx_byte_pos;
    logic [15:0] rx_last_len;

    always_ff @(posedge clk_rx) begin
        if (rst_rx) begin
            rx_count    <= 16'd0;
            rx_byte_pos <= 16'd0;
            rx_last_len <= 16'd0;
        end else if (s_axis_tvalid) begin
            if (s_axis_tlast) begin
                rx_count    <= rx_count + 16'd1;
                rx_last_len <= rx_byte_pos + 16'd1;
                rx_byte_pos <= 16'd0;
            end else begin
                rx_byte_pos <= rx_byte_pos + 16'd1;
            end
        end
    end

    // Gray-code the count before crossing domains.
    logic [15:0] rx_count_gray;
    always_ff @(posedge clk_rx) begin
        if (rst_rx) rx_count_gray <= 16'd0;
        else        rx_count_gray <= rx_count ^ (rx_count >> 1);
    end

    // --- Port A domain: 2-flop synchronizer, Gray -> binary ---
    logic [15:0] gray_sync0, gray_sync1;
    always_ff @(posedge clka) begin
        if (rsta) begin
            gray_sync0 <= 16'd0;
            gray_sync1 <= 16'd0;
        end else begin
            gray_sync0 <= rx_count_gray;
            gray_sync1 <= gray_sync0;
        end
    end

    logic [15:0] synced_count_bin;
    always_comb begin
        synced_count_bin[15] = gray_sync1[15];
        for (int b = 14; b >= 0; b--)
            synced_count_bin[b] = gray_sync1[b] ^ synced_count_bin[b+1];
    end

    // last_frame_len is read as-is with a single register stage for
    // metastability safety, no cross-domain sequencing guarantee beyond
    // that. Acceptable for a low-rate bring-up test (single test packets);
    // if REG_COUNT and REG_LAST_LEN are ever read a cycle apart while
    // back-to-back frames are arriving, LAST_LEN could reflect a newer
    // frame than the COUNT snapshot. Not a concern here -- flag before
    // relying on this for anything beyond manual bring-up checks.
    logic [15:0] last_len_sync0, last_len_sync1;
    always_ff @(posedge clka) begin
        last_len_sync0 <= rx_last_len;
        last_len_sync1 <= last_len_sync0;
    end

    always_ff @(posedge clka) begin
        if (ena) begin
            case (addra)
                REG_COUNT:    douta <= {16'd0, synced_count_bin};
                REG_LAST_LEN: douta <= {16'd0, last_len_sync1};
                default:      douta <= 32'd0;
            endcase
        end
    end

endmodule
