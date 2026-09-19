// Top-level tick-to-trade datapath: MAC RX -> parse key -> cache lookup
// -> stream cached response -> MAC TX. Cache refresh comes in on Port A,
// meant to be wired to an AXI BRAM Controller instance fed by XDMA in your
// block design (software refreshes a line with a plain MMIO pointer write
// into the mapped PCIe BAR).
import market_data_pkg::*;

module tick_to_trade_top (
    input  logic                  clk,     // MAC/datapath clock domain
    input  logic                  rst,

    // MAC RX AXI4-Stream
    input  logic [DATA_WIDTH-1:0] s_axis_tdata,
    input  logic [KEEP_WIDTH-1:0] s_axis_tkeep,
    input  logic                  s_axis_tvalid,
    input  logic                  s_axis_tlast,
    input  logic                  s_axis_tuser,

    // MAC TX AXI4-Stream
    output logic [DATA_WIDTH-1:0] m_axis_tdata,
    output logic [KEEP_WIDTH-1:0] m_axis_tkeep,
    output logic                  m_axis_tvalid,
    output logic                  m_axis_tlast,
    input  logic                  m_axis_tready,

    // Cache refresh port -- wire to axi_bram_ctrl's BRAM_PORTA
    // (bram_clk_a, bram_rst_a, bram_en_a, bram_we_a, bram_addr_a,
    //  bram_wrdata_a, bram_rddata_a) in your PCIe/XDMA clock domain.
    // NOTE: clka here is the AXI BRAM Controller's clock, which may differ
    // from `clk` above -- td_cache_bram's two ports are independently
    // clocked, so that's fine, but treat lines refreshed mid-read as
    // eventually-consistent (no read-modify-write hazard handling here).
    input  logic                          clka,
    input  logic                          rsta,
    input  logic                          ena,
    input  logic [LINE_WIDTH_BITS/8-1:0]  wea,
    input  logic [CACHE_ADDR_WIDTH-1:0]   addra,
    input  logic [LINE_WIDTH_BITS-1:0]    dina,
    output logic [LINE_WIDTH_BITS-1:0]    douta
);

    logic                        lookup_valid;
    logic [CACHE_ADDR_WIDTH-1:0] lookup_addr;

    logic                        enb;
    logic [CACHE_ADDR_WIDTH-1:0] addrb;
    logic [LINE_WIDTH_BITS-1:0]  doutb;

    logic                        resp_start;
    cache_line_t                 resp_line;
    logic                        tx_busy;

    udp_key_parser u_parser (
        .clk            (clk),
        .rst            (rst),
        .s_axis_tdata   (s_axis_tdata),
        .s_axis_tkeep   (s_axis_tkeep),
        .s_axis_tvalid  (s_axis_tvalid),
        .s_axis_tlast   (s_axis_tlast),
        .s_axis_tuser   (s_axis_tuser),
        .lookup_valid   (lookup_valid),
        .lookup_addr    (lookup_addr)
    );

    td_cache_bram u_cache (
        .clka   (clka), .rsta (rsta), .ena (ena), .wea (wea),
        .addra  (addra), .dina (dina), .douta (douta),
        .clkb   (clk),  .enb  (enb),  .addrb (addrb), .doutb (doutb)
    );

    cache_read_port u_read (
        .clk          (clk),
        .rst          (rst),
        .lookup_valid (lookup_valid),
        .lookup_addr  (lookup_addr),
        .enb          (enb),
        .addrb        (addrb),
        .doutb        (doutb),
        .resp_start   (resp_start),
        .resp_line    (resp_line)
    );

    tx_response_fsm u_tx (
        .clk            (clk),
        .rst            (rst),
        .resp_start     (resp_start),
        .resp_line      (resp_line),
        .busy           (tx_busy),
        .m_axis_tdata   (m_axis_tdata),
        .m_axis_tkeep   (m_axis_tkeep),
        .m_axis_tvalid  (m_axis_tvalid),
        .m_axis_tlast   (m_axis_tlast),
        .m_axis_tready  (m_axis_tready)
    );

endmodule
