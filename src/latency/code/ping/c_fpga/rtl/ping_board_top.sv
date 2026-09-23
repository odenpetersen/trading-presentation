// Board-level top for the FPGA ping responder on the ALINX AXKU3.
// No PCIe, no host software, no cache -- reuses ../../fpga/rtl's
// eth_mac_wrapper.sv (RGMII -> clean 8-bit RX+TX AXI4-Stream, self-
// contained POR, no PCIe dependency) straight into ping_mirror (the
// whole datapath). That wrapper is hardware-proven, not speculative:
// it's the same one eth_loopback_top.sv uses, which is currently
// programmed on this board and shows link_status=1 (1000M/full-duplex)
// over JTAG/VIO -- see ../../fpga/build/eth_loopback_top.xdc for the
// pin sourcing. Pin constraints here: build/ping_board_top.xdc, same
// pins.
//
// ASSUMES rx_mac_aclk and tx_mac_aclk come out as the same clock domain
// in this MAC configuration (both ultimately derived from gtx_clk at a
// fixed 1000Mbps) -- ping_mirror is single-clocked across s_axis/m_axis,
// so if bring-up shows they're not actually the same clock, this needs a
// small CDC FIFO between them, not a rewrite.
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
    logic       link_status, link_duplex;
    logic [1:0] link_speed;
    logic       rx_enable_status;

    eth_mac_wrapper u_eth (
        .clk200_p(clk200_p), .clk200_n(clk200_n),
        .rgmii_txd(rgmii_txd), .rgmii_tx_ctl(rgmii_tx_ctl), .rgmii_txc(rgmii_txc),
        .rgmii_rxd(rgmii_rxd), .rgmii_rx_ctl(rgmii_rx_ctl), .rgmii_rxc(rgmii_rxc),
        .mdio(mdio), .mdc(mdc), .phy_rst_n(phy_rst_n),
        .clk_rx(clk_rx), .rst_rx(rst_rx),
        .rx_tdata(rx_tdata), .rx_tvalid(rx_tvalid), .rx_tlast(rx_tlast), .rx_tuser(rx_tuser),
        .clk_tx(clk_tx), .rst_tx(rst_tx),
        .tx_tdata(tx_tdata), .tx_tvalid(tx_tvalid), .tx_tlast(tx_tlast), .tx_tuser(1'b0), .tx_tready(tx_tready),
        .link_status(link_status), .link_duplex(link_duplex), .link_speed(link_speed),
        .rx_enable_status(rx_enable_status)
    );

    ping_mirror u_mirror (
        .clk(clk_rx), .rst(rst_rx),
        .s_axis_tdata(rx_tdata), .s_axis_tkeep(1'b1),
        .s_axis_tvalid(rx_tvalid), .s_axis_tlast(rx_tlast), .s_axis_tuser(rx_tuser),
        .m_axis_tdata(tx_tdata), .m_axis_tkeep(),
        .m_axis_tvalid(tx_tvalid), .m_axis_tlast(tx_tlast), .m_axis_tready(tx_tready)
    );

    // JTAG-visible bring-up diagnostics, same pattern as
    // ../../fpga/rtl/eth_loopback_top.sv (eth_test_counter.sv is generic:
    // counts frames on any tvalid/tlast stream). Answers, independent of
    // whether a ping actually shows up on the wire: is RX seeing frames
    // at all, and is ping_mirror actually entering SEND for any of them?
    // tx_frame_count is clocked by clk_rx, not clk_tx, on the same
    // assumption noted above that they're the same domain here -- fine
    // for a debug counter even if that turns out wrong, just don't trust
    // it as proof either way if clk_rx/clk_tx do turn out distinct.
    logic [15:0] rx_frame_count, rx_last_frame_len;
    logic [15:0] tx_frame_count, tx_last_frame_len;

    eth_test_counter u_rx_counter (
        .clk(clk_rx), .rst(rst_rx),
        .s_axis_tvalid(rx_tvalid), .s_axis_tlast(rx_tlast),
        .frame_count(rx_frame_count), .last_frame_len(rx_last_frame_len)
    );

    eth_test_counter u_tx_counter (
        .clk(clk_rx), .rst(rst_rx),
        .s_axis_tvalid(tx_tvalid), .s_axis_tlast(tx_tlast),
        .frame_count(tx_frame_count), .last_frame_len(tx_last_frame_len)
    );

    vio_0 u_vio (
        .clk(clk_rx),
        .probe_in0(rx_frame_count), .probe_in1(rx_last_frame_len),
        .probe_in2(tx_frame_count),
        .probe_in3({link_speed, link_duplex, link_status}),
        .probe_in4({rx_enable_status, rst_rx})
    );

endmodule
