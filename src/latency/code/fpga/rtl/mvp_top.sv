// Bring-up MVP: RX-only. Wires the Ethernet MAC's RX AXI4-Stream into
// rx_packet_counter and exposes its register file (Port A) for an AXI
// BRAM Controller / XDMA to read. No TX -- this MVP only needs to prove
// "a packet arrived on the wire is visible to host software", so the TX
// AXI4-Stream into the MAC is simply held idle.
import market_data_pkg::*;

module mvp_top (
    // RX AXI4-Stream from eth_mac_0
    input  logic                  clk_rx,
    input  logic                  rst_rx,
    input  logic [DATA_WIDTH-1:0] s_axis_tdata,
    input  logic [KEEP_WIDTH-1:0] s_axis_tkeep,
    input  logic                  s_axis_tvalid,
    input  logic                  s_axis_tlast,
    input  logic                  s_axis_tuser,

    // TX AXI4-Stream to eth_mac_0 -- tied idle, this MVP sends nothing.
    output logic [DATA_WIDTH-1:0] m_axis_tdata,
    output logic [KEEP_WIDTH-1:0] m_axis_tkeep,
    output logic                  m_axis_tvalid,
    output logic                  m_axis_tlast,
    input  logic                  m_axis_tready,

    // Register file -- wire to axi_bram_ctrl's BRAM_PORTA (PCIe/XDMA clock domain)
    input  logic                  clka,
    input  logic                  rsta,
    input  logic                  ena,
    input  logic [3:0]            wea,
    input  logic [3:0]            addra,
    input  logic [31:0]           dina,
    output logic [31:0]           douta
);

    assign m_axis_tdata  = '0;
    assign m_axis_tkeep  = '0;
    assign m_axis_tvalid = 1'b0;
    assign m_axis_tlast  = 1'b0;

    rx_packet_counter u_counter (
        .clka(clka), .rsta(rsta), .ena(ena), .wea(wea), .addra(addra), .dina(dina), .douta(douta),
        .clk_rx(clk_rx), .rst_rx(rst_rx),
        .s_axis_tvalid(s_axis_tvalid), .s_axis_tlast(s_axis_tlast)
    );

endmodule
