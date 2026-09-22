// Ethernet RX/TX bring-up test: no PCIe at all. A received frame is
// buffered across the RX/TX clock domain boundary (eth_mac_0's RX and TX
// clocks are separate, nominally-125MHz-but-independent domains -- RX is
// recovered from the incoming RGMII clock, TX is locally generated) by
// axis_fifo_0, then retransmitted out the same port -- ping the board and
// the reply proves both RX and TX work. A VIO core exposes a running
// frame count and last-frame length live over JTAG, independent of
// whether the loopback/reply is actually visible on the wire.
module eth_loopback_top (
    input  logic         clk200_p,
    input  logic         clk200_n,

    output logic [3:0]  rgmii_txd,
    output logic         rgmii_tx_ctl,
    output logic         rgmii_txc,
    input  logic [3:0]  rgmii_rxd,
    input  logic         rgmii_rx_ctl,
    input  logic         rgmii_rxc,
    inout  logic         mdio,
    output logic         mdc,
    output logic         phy_rst_n
);

    logic       clk_rx, rst_rx;
    logic [7:0] rx_tdata;
    logic       rx_tvalid, rx_tlast, rx_tuser;

    logic       clk_tx, rst_tx;
    logic [7:0] tx_tdata;
    logic       tx_tvalid, tx_tlast, tx_tuser, tx_tready;
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
        .tx_tdata(tx_tdata), .tx_tvalid(tx_tvalid), .tx_tlast(tx_tlast), .tx_tuser(tx_tuser), .tx_tready(tx_tready),
        .link_status(link_status), .link_duplex(link_duplex), .link_speed(link_speed),
        .rx_enable_status(rx_enable_status)
    );

    // RX -> TX loopback across the (independent) RX/TX clock domains.
    // Note: eth_mac_0's RX AXI4-Stream has no tready input at all (a pure
    // push interface) -- if this FIFO is ever full when a frame arrives,
    // that frame is silently dropped, not stalled. Fine for this bring-up
    // test; would need a bigger FIFO or backpressure elsewhere for
    // sustained high-rate traffic.
    axis_fifo_0 u_loopback_fifo (
        .s_axis_aresetn(~rst_rx), .s_axis_aclk(clk_rx),
        .s_axis_tvalid(rx_tvalid), .s_axis_tready(), .s_axis_tdata(rx_tdata),
        .s_axis_tlast(rx_tlast), .s_axis_tuser(rx_tuser),
        .m_axis_aclk(clk_tx),
        .m_axis_tvalid(tx_tvalid), .m_axis_tready(tx_tready), .m_axis_tdata(tx_tdata),
        .m_axis_tlast(tx_tlast), .m_axis_tuser(tx_tuser)
    );

    // Observational tap: same RX stream, independent of the loopback path.
    logic [15:0] frame_count, last_frame_len;
    eth_test_counter u_counter (
        .clk(clk_rx), .rst(rst_rx),
        .s_axis_tvalid(rx_tvalid), .s_axis_tlast(rx_tlast),
        .frame_count(frame_count), .last_frame_len(last_frame_len)
    );

    vio_0 u_vio (
        .clk(clk_rx),
        .probe_in0(frame_count), .probe_in1(last_frame_len),
        .probe_in2({link_speed, link_duplex, link_status}),
        .probe_in3({rx_enable_status, rst_rx})
    );

    // Direct evidence: does the MAC's own RX AXI4-Stream ever show any
    // activity at all when traffic arrives? Settles whether the problem
    // is upstream (electrical/PHY) or in our own RTL, independent of the
    // frame-boundary logic in eth_test_counter.sv.
    ila_0 u_ila (
        .clk(clk_rx),
        .probe0(rst_rx), .probe1(rx_tvalid), .probe2(rx_tlast),
        .probe3(rx_tuser), .probe4(rx_tdata)
    );

endmodule
