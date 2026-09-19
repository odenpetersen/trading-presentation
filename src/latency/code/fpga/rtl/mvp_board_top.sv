// Board-level top for the Ethernet RX-counter MVP on the ALINX AXKU3.
// Split into pcie_endpoint.sv (PCIe -> one clean 256-bit AXI4 master),
// reg_file_bridge.sv (that AXI4 -> native BRAM Port A), and
// eth_mac_wrapper.sv (RGMII -> one clean RX AXI4-Stream) so this file is
// just the top-level connections between them, not ~150 raw IP signals.
//
// Pin constraints: build/mvp_board_top.xdc, sourced from the AXKU3 User
// Manual REV1.1 (Table 11, Table 13) -- PHY is a JL21221D, strapped for
// PHY-side RGMII delay (see that file's header comment for what that
// implies for eth_mac_0's RGMII delay IP setting -- verify before
// implementation).
//
// KNOWN GAP: eth_mac_0's AXI-Lite management interface is tied idle (no
// MDIO configuration performed, see eth_mac_wrapper.sv). If RX traffic
// doesn't appear once this is programmed onto real hardware, this is the
// next thing to add.
module mvp_board_top (
    input  logic         sys_clk_p,
    input  logic         sys_clk_n,
    input  logic         sys_rst_n,
    output logic [7:0]   pci_exp_txp,
    output logic [7:0]   pci_exp_txn,
    input  logic [7:0]   pci_exp_rxp,
    input  logic [7:0]   pci_exp_rxn,

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

    // --- PCIe endpoint: gives us one clean 256-bit AXI4 master ----------
    logic axi_aclk, axi_aresetn;
    logic [3:0]   axi_awid, axi_arid, axi_bid, axi_rid;
    logic [31:0]  axi_awaddr, axi_araddr;
    logic [7:0]   axi_awlen, axi_arlen;
    logic [2:0]   axi_awsize, axi_arsize;
    logic [1:0]   axi_awburst, axi_arburst, axi_bresp, axi_rresp;
    logic [2:0]   axi_awprot, axi_arprot;
    logic         axi_awvalid, axi_awready, axi_awlock;
    logic [3:0]   axi_awcache, axi_arcache;
    logic [255:0] axi_wdata, axi_rdata;
    logic [31:0]  axi_wstrb;
    logic         axi_wlast, axi_wvalid, axi_wready;
    logic         axi_bvalid, axi_bready;
    logic         axi_arvalid, axi_arready, axi_arlock;
    logic         axi_rlast, axi_rvalid, axi_rready;

    pcie_endpoint u_pcie (
        .sys_clk_p(sys_clk_p), .sys_clk_n(sys_clk_n), .sys_rst_n(sys_rst_n),
        .pci_exp_txp(pci_exp_txp), .pci_exp_txn(pci_exp_txn),
        .pci_exp_rxp(pci_exp_rxp), .pci_exp_rxn(pci_exp_rxn),
        .axi_aclk(axi_aclk), .axi_aresetn(axi_aresetn),
        .m_axi_awid(axi_awid), .m_axi_awaddr(axi_awaddr), .m_axi_awlen(axi_awlen),
        .m_axi_awsize(axi_awsize), .m_axi_awburst(axi_awburst), .m_axi_awprot(axi_awprot),
        .m_axi_awvalid(axi_awvalid), .m_axi_awready(axi_awready),
        .m_axi_awlock(axi_awlock), .m_axi_awcache(axi_awcache),
        .m_axi_wdata(axi_wdata), .m_axi_wstrb(axi_wstrb), .m_axi_wlast(axi_wlast),
        .m_axi_wvalid(axi_wvalid), .m_axi_wready(axi_wready),
        .m_axi_bid(axi_bid), .m_axi_bresp(axi_bresp), .m_axi_bvalid(axi_bvalid), .m_axi_bready(axi_bready),
        .m_axi_arid(axi_arid), .m_axi_araddr(axi_araddr), .m_axi_arlen(axi_arlen),
        .m_axi_arsize(axi_arsize), .m_axi_arburst(axi_arburst), .m_axi_arprot(axi_arprot),
        .m_axi_arvalid(axi_arvalid), .m_axi_arready(axi_arready),
        .m_axi_arlock(axi_arlock), .m_axi_arcache(axi_arcache),
        .m_axi_rid(axi_rid), .m_axi_rdata(axi_rdata), .m_axi_rresp(axi_rresp),
        .m_axi_rlast(axi_rlast), .m_axi_rvalid(axi_rvalid), .m_axi_rready(axi_rready)
    );

    // --- AXI4 -> native BRAM Port A --------------------------------------
    logic        bram_rst_a, bram_clk_a, bram_en_a;
    logic [3:0]  bram_we_a;
    logic [11:0] bram_addr_a;
    logic [31:0] bram_wrdata_a, bram_rddata_a;

    reg_file_bridge u_reg_bridge (
        .s_axi_aclk(axi_aclk), .s_axi_aresetn(axi_aresetn),
        .s_axi_awid(axi_awid), .s_axi_awaddr(axi_awaddr), .s_axi_awlen(axi_awlen),
        .s_axi_awsize(axi_awsize), .s_axi_awburst(axi_awburst), .s_axi_awprot(axi_awprot),
        .s_axi_awvalid(axi_awvalid), .s_axi_awready(axi_awready),
        .s_axi_awlock(axi_awlock), .s_axi_awcache(axi_awcache),
        .s_axi_wdata(axi_wdata), .s_axi_wstrb(axi_wstrb), .s_axi_wlast(axi_wlast),
        .s_axi_wvalid(axi_wvalid), .s_axi_wready(axi_wready),
        .s_axi_bid(axi_bid), .s_axi_bresp(axi_bresp), .s_axi_bvalid(axi_bvalid), .s_axi_bready(axi_bready),
        .s_axi_arid(axi_arid), .s_axi_araddr(axi_araddr), .s_axi_arlen(axi_arlen),
        .s_axi_arsize(axi_arsize), .s_axi_arburst(axi_arburst), .s_axi_arprot(axi_arprot),
        .s_axi_arvalid(axi_arvalid), .s_axi_arready(axi_arready),
        .s_axi_arlock(axi_arlock), .s_axi_arcache(axi_arcache),
        .s_axi_rid(axi_rid), .s_axi_rdata(axi_rdata), .s_axi_rresp(axi_rresp),
        .s_axi_rlast(axi_rlast), .s_axi_rvalid(axi_rvalid), .s_axi_rready(axi_rready),
        .bram_rst_a(bram_rst_a), .bram_clk_a(bram_clk_a), .bram_en_a(bram_en_a),
        .bram_we_a(bram_we_a), .bram_addr_a(bram_addr_a),
        .bram_wrdata_a(bram_wrdata_a), .bram_rddata_a(bram_rddata_a)
    );

    // --- Ethernet MAC: RGMII -> one clean RX AXI4-Stream -----------------
    logic       clk_rx, rst_rx;
    logic [7:0] rx_tdata;
    logic       rx_tvalid, rx_tlast, rx_tuser;

    eth_mac_wrapper u_eth (
        .axi_aclk(axi_aclk), .axi_aresetn(axi_aresetn),
        .clk200_p(clk200_p), .clk200_n(clk200_n),
        .rgmii_txd(rgmii_txd), .rgmii_tx_ctl(rgmii_tx_ctl), .rgmii_txc(rgmii_txc),
        .rgmii_rxd(rgmii_rxd), .rgmii_rx_ctl(rgmii_rx_ctl), .rgmii_rxc(rgmii_rxc),
        .mdio(mdio), .mdc(mdc), .phy_rst_n(phy_rst_n),
        .clk_rx(clk_rx), .rst_rx(rst_rx),
        .rx_tdata(rx_tdata), .rx_tvalid(rx_tvalid), .rx_tlast(rx_tlast), .rx_tuser(rx_tuser)
    );

    // --- Our actual logic -------------------------------------------------
    mvp_top u_mvp (
        .clk_rx(clk_rx), .rst_rx(rst_rx),
        .s_axis_tdata(rx_tdata), .s_axis_tkeep(1'b1),
        .s_axis_tvalid(rx_tvalid), .s_axis_tlast(rx_tlast), .s_axis_tuser(rx_tuser),
        .m_axis_tdata(), .m_axis_tkeep(), .m_axis_tvalid(), .m_axis_tlast(), .m_axis_tready(1'b1),
        .clka(bram_clk_a), .rsta(bram_rst_a), .ena(bram_en_a), .wea(bram_we_a),
        .addra(bram_addr_a[3:0]), .dina(bram_wrdata_a), .douta(bram_rddata_a)
    );

endmodule
