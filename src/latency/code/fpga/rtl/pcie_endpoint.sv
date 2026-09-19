// PCIe endpoint: refclk buffering + xdma_0, collapsed into one clean AXI4
// (256-bit) master interface. Everything PCIe-specific lives here so
// mvp_board_top.sv doesn't have to see xdma_0's ~100 raw ports.
module pcie_endpoint (
    input  logic         sys_clk_p,
    input  logic         sys_clk_n,
    input  logic         sys_rst_n,
    output logic [7:0]   pci_exp_txp,
    output logic [7:0]   pci_exp_txn,
    input  logic [7:0]   pci_exp_rxp,
    input  logic [7:0]   pci_exp_rxn,

    output logic         axi_aclk,
    output logic         axi_aresetn,

    // AXI4 master, 256-bit -- consumer is reg_file_bridge.sv
    output logic [3:0]   m_axi_awid,
    output logic [31:0]  m_axi_awaddr,
    output logic [7:0]   m_axi_awlen,
    output logic [2:0]   m_axi_awsize,
    output logic [1:0]   m_axi_awburst,
    output logic [2:0]   m_axi_awprot,
    output logic         m_axi_awvalid,
    input  logic         m_axi_awready,
    output logic         m_axi_awlock,
    output logic [3:0]   m_axi_awcache,
    output logic [255:0] m_axi_wdata,
    output logic [31:0]  m_axi_wstrb,
    output logic         m_axi_wlast,
    output logic         m_axi_wvalid,
    input  logic         m_axi_wready,
    input  logic [3:0]   m_axi_bid,
    input  logic [1:0]   m_axi_bresp,
    input  logic         m_axi_bvalid,
    output logic         m_axi_bready,
    output logic [3:0]   m_axi_arid,
    output logic [31:0]  m_axi_araddr,
    output logic [7:0]   m_axi_arlen,
    output logic [2:0]   m_axi_arsize,
    output logic [1:0]   m_axi_arburst,
    output logic [2:0]   m_axi_arprot,
    output logic         m_axi_arvalid,
    input  logic         m_axi_arready,
    output logic         m_axi_arlock,
    output logic [3:0]   m_axi_arcache,
    input  logic [3:0]   m_axi_rid,
    input  logic [255:0] m_axi_rdata,
    input  logic [1:0]   m_axi_rresp,
    input  logic         m_axi_rlast,
    input  logic         m_axi_rvalid,
    output logic         m_axi_rready
);

    logic sys_clk, sys_clk_gt;
    IBUFDS_GTE4 u_sys_clk_ibuf (
        .I(sys_clk_p), .IB(sys_clk_n), .CEB(1'b0),
        .O(sys_clk_gt), .ODIV2(sys_clk)
    );

    logic        axi_ctl_aresetn;
    logic [5:0]  cfg_ltssm_state;
    logic        user_lnk_up;
    logic [0:0]  usr_irq_req = 1'b0;
    logic [0:0]  usr_irq_ack;
    logic        msi_enable;
    logic [2:0]  msi_vector_width;
    logic        interrupt_out;

    xdma_0 u_xdma (
        .sys_clk(sys_clk), .sys_clk_gt(sys_clk_gt), .sys_rst_n(sys_rst_n),
        .cfg_ltssm_state(cfg_ltssm_state), .user_lnk_up(user_lnk_up),
        .pci_exp_txp(pci_exp_txp), .pci_exp_txn(pci_exp_txn),
        .pci_exp_rxp(pci_exp_rxp), .pci_exp_rxn(pci_exp_rxn),
        .axi_aclk(axi_aclk), .axi_aresetn(axi_aresetn), .axi_ctl_aresetn(axi_ctl_aresetn),
        .usr_irq_req(usr_irq_req), .usr_irq_ack(usr_irq_ack),
        .msi_enable(msi_enable), .msi_vector_width(msi_vector_width),
        .m_axib_awid(m_axi_awid), .m_axib_awaddr(m_axi_awaddr), .m_axib_awlen(m_axi_awlen),
        .m_axib_awsize(m_axi_awsize), .m_axib_awburst(m_axi_awburst), .m_axib_awprot(m_axi_awprot),
        .m_axib_awvalid(m_axi_awvalid), .m_axib_awready(m_axi_awready),
        .m_axib_awlock(m_axi_awlock), .m_axib_awcache(m_axi_awcache),
        .m_axib_wdata(m_axi_wdata), .m_axib_wstrb(m_axi_wstrb), .m_axib_wlast(m_axi_wlast),
        .m_axib_wvalid(m_axi_wvalid), .m_axib_wready(m_axi_wready),
        .m_axib_bid(m_axi_bid), .m_axib_bresp(m_axi_bresp), .m_axib_bvalid(m_axi_bvalid), .m_axib_bready(m_axi_bready),
        .m_axib_arid(m_axi_arid), .m_axib_araddr(m_axi_araddr), .m_axib_arlen(m_axi_arlen),
        .m_axib_arsize(m_axi_arsize), .m_axib_arburst(m_axi_arburst), .m_axib_arprot(m_axi_arprot),
        .m_axib_arvalid(m_axi_arvalid), .m_axib_arready(m_axi_arready),
        .m_axib_arlock(m_axi_arlock), .m_axib_arcache(m_axi_arcache),
        .m_axib_rid(m_axi_rid), .m_axib_rdata(m_axi_rdata), .m_axib_rresp(m_axi_rresp),
        .m_axib_rlast(m_axi_rlast), .m_axib_rvalid(m_axi_rvalid), .m_axib_rready(m_axi_rready),
        // Unused secondary interfaces on this core, tied idle.
        .s_axil_awaddr('0), .s_axil_awprot('0), .s_axil_awvalid(1'b0), .s_axil_awready(),
        .s_axil_wdata('0), .s_axil_wstrb('0), .s_axil_wvalid(1'b0), .s_axil_wready(),
        .s_axil_bvalid(), .s_axil_bresp(), .s_axil_bready(1'b1),
        .s_axil_araddr('0), .s_axil_arprot('0), .s_axil_arvalid(1'b0), .s_axil_arready(),
        .s_axil_rdata(), .s_axil_rresp(), .s_axil_rvalid(), .s_axil_rready(1'b1),
        .interrupt_out(interrupt_out),
        .s_axib_awid('0), .s_axib_awaddr('0), .s_axib_awregion('0), .s_axib_awlen('0),
        .s_axib_awsize('0), .s_axib_awburst('0), .s_axib_awvalid(1'b0),
        .s_axib_wdata('0), .s_axib_wstrb('0), .s_axib_wlast(1'b0), .s_axib_wvalid(1'b0),
        .s_axib_bready(1'b1),
        .s_axib_arid('0), .s_axib_araddr('0), .s_axib_arregion('0), .s_axib_arlen('0),
        .s_axib_arsize('0), .s_axib_arburst('0), .s_axib_arvalid(1'b0), .s_axib_rready(1'b1),
        .s_axib_awready(), .s_axib_wready(), .s_axib_bid(), .s_axib_bresp(), .s_axib_bvalid(),
        .s_axib_arready(), .s_axib_rid(), .s_axib_rdata(), .s_axib_rresp(), .s_axib_rlast(), .s_axib_rvalid()
    );

endmodule
