// Drives cache BRAM Port B from the parser's lookup pulse, and unpacks the
// registered read data one cycle later into a cache_line_t + start pulse
// for tx_response_fsm.
import market_data_pkg::*;

module cache_read_port (
    input  logic                        clk,
    input  logic                        rst,

    input  logic                        lookup_valid,
    input  logic [CACHE_ADDR_WIDTH-1:0] lookup_addr,

    output logic                        enb,
    output logic [CACHE_ADDR_WIDTH-1:0] addrb,
    input  logic [LINE_WIDTH_BITS-1:0]  doutb,

    output logic                        resp_start,
    output cache_line_t                 resp_line
);

    assign enb   = lookup_valid;
    assign addrb = lookup_addr;

    logic doutb_valid;
    always_ff @(posedge clk) begin
        if (rst) doutb_valid <= 1'b0;
        else     doutb_valid <= lookup_valid;
    end

    always_comb begin
        resp_line.valid     = doutb[LINE_VALID_BIT];
        resp_line.len_bytes = doutb[LINE_LEN_LSB +: LINE_LEN_WIDTH];
        resp_line.frame     = doutb[LINE_DATA_LSB +: MAX_FRAME_BYTES*8];
    end

    // Only fire on an actual cache hit -- a miss (valid=0, e.g. instrument
    // never registered by software) silently drops the packet from the
    // fast path instead of emitting garbage.
    assign resp_start = doutb_valid && resp_line.valid;

endmodule
