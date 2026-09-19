// Ethernet MAC (RGMII) wrapper with both RX and TX AXI4-Stream exposed --
// adapted from ../../fpga/rtl/eth_mac_wrapper.sv (which ties TX idle,
// since the tick-to-trade MVP only needed RX). This ping demo needs no
// PCIe at all (no cache refresh, no host software in the loop), so
// there's no PCIe-derived axi_aclk to hang the MAC's 125MHz off of --
// instead this reuses the board's existing 200MHz IDELAYCTRL reference
// oscillator (same clk200_p/n pins, same proven pin constraints) as
// clk_wiz_0's input too, and generates its own power-on reset instead of
// taking one in from a PCIe reset pin.
module eth_mac_wrapper_txrx (
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
    output logic         phy_rst_n,

    output logic         clk_rx,       // = rx_mac_aclk, RX AXI4-Stream's clock domain
    output logic         rst_rx,
    output logic [7:0]   rx_tdata,
    output logic          rx_tvalid,
    output logic          rx_tlast,
    output logic          rx_tuser,

    output logic         clk_tx,       // = tx_mac_aclk, TX AXI4-Stream's clock domain
    output logic         rst_tx,
    input  logic [7:0]   tx_tdata,
    input  logic          tx_tvalid,
    input  logic          tx_tlast,
    output logic          tx_tready
);

    logic clk200;
    IBUFGDS u_clk200_ibuf (.I(clk200_p), .IB(clk200_n), .O(clk200));

    // Power-on reset: no external reset pin on this standalone (no PCIe)
    // design, so hold reset for a handful of cycles after configuration
    // instead -- a standard FPGA idiom, relying on the bitstream's
    // flip-flop initial values, not an external signal.
    logic [3:0] por_cnt = '0;
    logic       aresetn;
    always_ff @(posedge clk200) if (por_cnt != 4'hF) por_cnt <= por_cnt + 1'b1;
    assign aresetn = (por_cnt == 4'hF);

    logic clk_125, clk_125_locked;
    clk_wiz_0 u_clk_wiz (
        .clk_in1(clk200), .reset(~aresetn),
        .clk_out1(clk_125), .locked(clk_125_locked)
    );

    // IODELAY_GROUP must match the group name eth_mac_0 tags its own
    // IODELAY cells with -- see ../../fpga/rtl/eth_mac_wrapper.sv, this
    // was confirmed against a real DRC error there, not guessed.
    (* IODELAY_GROUP = "tri_mode_ethernet_mac_iodelay_grp" *)
    IDELAYCTRL #(
        .SIM_DEVICE("ULTRASCALE_PLUS")
    ) u_idelayctrl (
        .REFCLK(clk200),
        .RST(~aresetn),
        .RDY()
    );

    logic [4:0]  rx_axis_filter_tuser;
    logic        rx_enable;
    logic [27:0] rx_statistics_vector;
    logic        rx_statistics_valid;
    logic        tx_enable;
    logic [31:0] tx_statistics_vector;
    logic        tx_statistics_valid;
    logic        speedis100, speedis10100;
    logic        inband_link_status, inband_duplex_status;
    logic [1:0]  inband_clock_speed;
    logic        mac_irq;

    assign phy_rst_n = aresetn;

    eth_mac_0 u_eth_mac (
        .s_axi_aclk(clk200), .s_axi_resetn(aresetn),
        .gtx_clk(clk_125), .glbl_rstn(aresetn),
        .rx_axi_rstn(aresetn), .tx_axi_rstn(aresetn),
        .rx_statistics_vector(rx_statistics_vector), .rx_statistics_valid(rx_statistics_valid),
        .rx_mac_aclk(clk_rx), .rx_reset(rst_rx), .rx_enable(rx_enable),
        .rx_axis_filter_tuser(rx_axis_filter_tuser),
        .rx_axis_mac_tdata(rx_tdata), .rx_axis_mac_tvalid(rx_tvalid),
        .rx_axis_mac_tlast(rx_tlast), .rx_axis_mac_tuser(rx_tuser),
        .tx_ifg_delay('0),
        .tx_statistics_vector(tx_statistics_vector), .tx_statistics_valid(tx_statistics_valid),
        .tx_mac_aclk(clk_tx), .tx_reset(rst_tx), .tx_enable(tx_enable),
        .tx_axis_mac_tdata(tx_tdata), .tx_axis_mac_tvalid(tx_tvalid), .tx_axis_mac_tlast(tx_tlast),
        .tx_axis_mac_tuser(1'b0), .tx_axis_mac_tready(tx_tready),
        .pause_req(1'b0), .pause_val('0),
        .speedis100(speedis100), .speedis10100(speedis10100),
        .rgmii_txd(rgmii_txd), .rgmii_tx_ctl(rgmii_tx_ctl), .rgmii_txc(rgmii_txc),
        .rgmii_rxd(rgmii_rxd), .rgmii_rx_ctl(rgmii_rx_ctl), .rgmii_rxc(rgmii_rxc),
        .inband_link_status(inband_link_status), .inband_clock_speed(inband_clock_speed),
        .inband_duplex_status(inband_duplex_status),
        .mdio(mdio), .mdc(mdc),
        // AXI-Lite management interface tied idle -- no MDIO config
        // performed, same known gap as ../../fpga/rtl/eth_mac_wrapper.sv.
        .s_axi_awaddr('0), .s_axi_awvalid(1'b0), .s_axi_awready(),
        .s_axi_wdata('0), .s_axi_wvalid(1'b0), .s_axi_wready(),
        .s_axi_bresp(), .s_axi_bvalid(), .s_axi_bready(1'b1),
        .s_axi_araddr('0), .s_axi_arvalid(1'b0), .s_axi_arready(),
        .s_axi_rdata(), .s_axi_rresp(), .s_axi_rvalid(), .s_axi_rready(1'b1),
        .mac_irq(mac_irq)
    );

endmodule
