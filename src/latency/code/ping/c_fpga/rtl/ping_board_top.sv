// Board-level top for the FPGA ping responder on the ALINX AXKU3.
// No PCIe, no host software, no cache -- eth_mac_wrapper_txrx (RGMII ->
// clean 8-bit RX+TX AXI4-Stream) straight into ping_mirror (the whole
// datapath). Pin constraints: build/ping_board_top.xdc, reusing the same
// proven RGMII + clk200 pins as ../../fpga/build/mvp_board_top.xdc.
//
// ASSUMES rx_mac_aclk and tx_mac_aclk come out as the same clock domain
// in this MAC configuration (both ultimately derived from gtx_clk at a
// fixed 1000Mbps) -- ping_mirror is single-clocked across s_axis/m_axis,
// so if bring-up shows they're not actually the same clock, this needs a
// small CDC FIFO between them, not a rewrite. Same "verify before
// implementation" gap as the RGMII delay mode note in
// ../../fpga/build/mvp_board_top.xdc -- untested on real hardware yet,
// like the rest of this project's FPGA side.
import ping_pkg::*;

module ping_board_top (
    input  logic         clk200_p,
    input  logic         clk200_n,

    output logic [3:0]   rgmii_txd,
    output logic         rgmii_tx_ctl,
    output logic         rgmii_txc,
    input  logic [3:0]   rgmii_rxd,
    input  logic         rgmii_rx_ctl,
    input  logic         rgmii_rxc,
    inout  logic         mdio,
    output logic         mdc,
    output logic         phy_rst_n
);

    logic       clk_rx, rst_rx, clk_tx, rst_tx;
    logic [7:0] rx_tdata, tx_tdata;
    logic       rx_tvalid, rx_tlast, rx_tuser;
    logic       tx_tvalid, tx_tlast, tx_tready;

    eth_mac_wrapper_txrx u_eth (
        .clk200_p(clk200_p), .clk200_n(clk200_n),
        .rgmii_txd(rgmii_txd), .rgmii_tx_ctl(rgmii_tx_ctl), .rgmii_txc(rgmii_txc),
        .rgmii_rxd(rgmii_rxd), .rgmii_rx_ctl(rgmii_rx_ctl), .rgmii_rxc(rgmii_rxc),
        .mdio(mdio), .mdc(mdc), .phy_rst_n(phy_rst_n),
        .clk_rx(clk_rx), .rst_rx(rst_rx),
        .rx_tdata(rx_tdata), .rx_tvalid(rx_tvalid), .rx_tlast(rx_tlast), .rx_tuser(rx_tuser),
        .clk_tx(clk_tx), .rst_tx(rst_tx),
        .tx_tdata(tx_tdata), .tx_tvalid(tx_tvalid), .tx_tlast(tx_tlast), .tx_tready(tx_tready)
    );

    ping_mirror u_mirror (
        .clk(clk_rx), .rst(rst_rx),
        .s_axis_tdata(rx_tdata), .s_axis_tkeep(1'b1),
        .s_axis_tvalid(rx_tvalid), .s_axis_tlast(rx_tlast), .s_axis_tuser(rx_tuser),
        .m_axis_tdata(tx_tdata), .m_axis_tkeep(),
        .m_axis_tvalid(tx_tvalid), .m_axis_tlast(tx_tlast), .m_axis_tready(tx_tready)
    );

endmodule
