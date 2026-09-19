// True dual-port cache memory, hand-written in the canonical form Vivado
// infers as block RAM.
//
// Port A: native-BRAM-style port (byte-write-enable, registered read data),
// signal names/timing match what Xilinx's AXI BRAM Controller (PG245)
// expects on its BRAM_PORTA interface -- wire this port directly to the
// axi_bram_ctrl instance's bram_addr_a/bram_wrdata_a/bram_rddata_a/
// bram_en_a/bram_we_a/bram_clk_a/bram_rst_a signals. That's how software,
// via XDMA -> AXI4 -> axi_bram_ctrl -> here, refreshes a cache line with a
// plain pointer write.
//
// Port B: plain synchronous read, used by the RX datapath.
import market_data_pkg::*;

module td_cache_bram (
    // Port A -- AXI BRAM Controller side (cache refresh from software)
    input  logic                            clka,
    input  logic                            rsta,
    input  logic                            ena,
    input  logic [LINE_WIDTH_BITS/8-1:0]    wea,       // per-byte write enable
    input  logic [CACHE_ADDR_WIDTH-1:0]     addra,
    input  logic [LINE_WIDTH_BITS-1:0]      dina,
    output logic [LINE_WIDTH_BITS-1:0]      douta,

    // Port B -- datapath read side
    input  logic                            clkb,
    input  logic                            enb,
    input  logic [CACHE_ADDR_WIDTH-1:0]     addrb,
    output logic [LINE_WIDTH_BITS-1:0]      doutb
);

    (* ram_style = "block" *)
    logic [LINE_WIDTH_BITS-1:0] mem [0:CACHE_DEPTH-1];

    always_ff @(posedge clka) begin
        if (ena) begin
            for (int b = 0; b < LINE_WIDTH_BITS/8; b++)
                if (wea[b]) mem[addra][b*8 +: 8] <= dina[b*8 +: 8];
            douta <= mem[addra];
        end
    end

    always_ff @(posedge clkb) begin
        if (enb)
            doutb <= mem[addrb];
    end

endmodule
