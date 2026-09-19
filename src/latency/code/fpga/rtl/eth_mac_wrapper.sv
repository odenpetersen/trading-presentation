// Ethernet MAC (RGMII) + its 125MHz clock generation, collapsed to just
// the RGMII/MDIO pins plus clean RX/TX AXI4-Stream ports. No PCIe/XDMA
// dependency at all -- clocked entirely from the board's 200MHz
// oscillator, reset via a simple internal power-on-reset generator
// (nothing external provides a reset now that XDMA/PERST# is gone).
// eth_mac_0's AXI-Lite management interface is tied idle -- no MDIO
// config performed, see fpga/README.md's known gap.
module eth_mac_wrapper (
    // 200MHz differential reference: IDELAYCTRL calibration AND the
    // source for gtx_clk via clk_wiz_0 (200->125MHz). One of the
    // module's two onboard oscillators (AXKU3 manual Table 6, B84_L5_P/N,
    // AC13/AC14) -- shared with the DDR4 controller's own reference, not
    // exclusive to this use.
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

    output logic         clk_rx,       // = rx_mac_aclk, the RX AXI4-Stream's own clock domain
    output logic         rst_rx,       // = rx_reset
    output logic [7:0]   rx_tdata,
    output logic          rx_tvalid,
    output logic          rx_tlast,
    output logic          rx_tuser,

    output logic          clk_tx,       // = tx_mac_aclk, the TX AXI4-Stream's own clock domain
    output logic          rst_tx,       // = tx_reset
    input  logic [7:0]   tx_tdata,
    input  logic          tx_tvalid,
    input  logic          tx_tlast,
    input  logic          tx_tuser,
    output logic          tx_tready,

    // RGMII in-band link status -- no MDIO needed, the PHY encodes this
    // directly on the RX bus during idle. First thing to check before
    // assuming an RTL bug if no traffic is ever seen.
    output logic          link_status,
    output logic          link_duplex,
    output logic [1:0]    link_speed,

    // Further diagnostics: is RX actually out of reset, and does the MAC
    // itself report its receiver block as operational?
    output logic          rx_enable_status
);

    logic clk200;
    IBUFGDS u_clk200_ibuf (.I(clk200_p), .IB(clk200_n), .O(clk200));

    // Simple power-on-reset: hold reset for the first 16 clk200 cycles
    // after configuration, then release. Nothing external (no PERST#,
    // no host) provides a reset in this design, unlike the PCIe version.
    logic [3:0] por_count = '0;
    logic       por_rst_n = 1'b0;
    always_ff @(posedge clk200) begin
        if (por_count != 4'hF) begin
            por_count <= por_count + 4'd1;
            por_rst_n <= 1'b0;
        end else begin
            por_rst_n <= 1'b1;
        end
    end

    logic clk_125, clk_125_locked;
    clk_wiz_0 u_clk_wiz (
        .clk_in1(clk200), .reset(~por_rst_n),
        .clk_out1(clk_125), .locked(clk_125_locked)
    );

    // IDELAYCTRL for eth_mac_0's internal RGMII IODELAY primitives.
    // IODELAY_GROUP must match the group name eth_mac_0 tags its own
    // IODELAY cells with -- confirmed via the DRC error this fixes
    // ('tri_mode_ethernet_mac_iodelay_grp'), not guessed.
    (* IODELAY_GROUP = "tri_mode_ethernet_mac_iodelay_grp" *)
    IDELAYCTRL #(
        .SIM_DEVICE("ULTRASCALE_PLUS")  // defaults to 7SERIES otherwise -- caught by bitgen DRC
    ) u_idelayctrl (
        .REFCLK(clk200),
        .RST(~por_rst_n),
        .RDY()
    );

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

    assign link_status = inband_link_status;
    assign link_duplex = inband_duplex_status;
    assign link_speed  = inband_clock_speed;
    assign rx_enable_status = rx_enable;

    assign phy_rst_n = por_rst_n; // simplest possible sequencing for bring-up; revisit if the manual specifies otherwise

    eth_mac_0 u_eth_mac (
        .s_axi_aclk(clk_125), .s_axi_resetn(por_rst_n),
        .gtx_clk(clk_125), .glbl_rstn(por_rst_n),
        .rx_axi_rstn(por_rst_n), .tx_axi_rstn(por_rst_n),
        .rx_statistics_vector(rx_statistics_vector), .rx_statistics_valid(rx_statistics_valid),
        .rx_mac_aclk(clk_rx), .rx_reset(rst_rx), .rx_enable(rx_enable),
        .rx_axis_mac_tdata(rx_tdata), .rx_axis_mac_tvalid(rx_tvalid),
        .rx_axis_mac_tlast(rx_tlast), .rx_axis_mac_tuser(rx_tuser),
        .tx_ifg_delay('0),
        .tx_statistics_vector(tx_statistics_vector), .tx_statistics_valid(tx_statistics_valid),
        .tx_mac_aclk(clk_tx), .tx_reset(rst_tx), .tx_enable(tx_enable),
        .tx_axis_mac_tdata(tx_tdata), .tx_axis_mac_tvalid(tx_tvalid), .tx_axis_mac_tlast(tx_tlast),
        .tx_axis_mac_tuser(tx_tuser), .tx_axis_mac_tready(tx_tready),
        .pause_req(1'b0), .pause_val('0),
        .speedis100(speedis100), .speedis10100(speedis10100),
        .rgmii_txd(rgmii_txd), .rgmii_tx_ctl(rgmii_tx_ctl), .rgmii_txc(rgmii_txc),
        .rgmii_rxd(rgmii_rxd), .rgmii_rx_ctl(rgmii_rx_ctl), .rgmii_rxc(rgmii_rxc),
        .inband_link_status(inband_link_status), .inband_clock_speed(inband_clock_speed),
        .inband_duplex_status(inband_duplex_status),
        .mdio(mdio), .mdc(mdc),
        // AXI-Lite management interface tied idle -- no MDIO config performed (see README known gap)
        .s_axi_awaddr('0), .s_axi_awvalid(1'b0), .s_axi_awready(),
        .s_axi_wdata('0), .s_axi_wvalid(1'b0), .s_axi_wready(),
        .s_axi_bresp(), .s_axi_bvalid(), .s_axi_bready(1'b1),
        .s_axi_araddr('0), .s_axi_arvalid(1'b0), .s_axi_arready(),
        .s_axi_rdata(), .s_axi_rresp(), .s_axi_rvalid(), .s_axi_rready(1'b1),
        .mac_irq(mac_irq)
    );

endmodule
