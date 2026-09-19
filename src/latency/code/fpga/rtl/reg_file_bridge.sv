// Bridges a 256-bit AXI4 master (from pcie_endpoint.sv) down to the
// native-BRAM Port A interface our register file modules expect.
// dwidth_conv_0 narrows 256->32 bits; axi_bram_ctrl_0 turns AXI4 into the
// simple clock/enable/address/data protocol. All the intermediate 32-bit
// AXI wiring stays internal to this file.
module reg_file_bridge (
    input  logic          s_axi_aclk,
    input  logic          s_axi_aresetn,

    input  logic [3:0]    s_axi_awid,
    input  logic [31:0]   s_axi_awaddr,
    input  logic [7:0]    s_axi_awlen,
    input  logic [2:0]    s_axi_awsize,
    input  logic [1:0]    s_axi_awburst,
    input  logic [2:0]    s_axi_awprot,
    input  logic          s_axi_awvalid,
    output logic          s_axi_awready,
    input  logic          s_axi_awlock,
    input  logic [3:0]    s_axi_awcache,
    input  logic [255:0]  s_axi_wdata,
    input  logic [31:0]   s_axi_wstrb,
    input  logic          s_axi_wlast,
    input  logic          s_axi_wvalid,
    output logic          s_axi_wready,
    output logic [3:0]    s_axi_bid,
    output logic [1:0]    s_axi_bresp,
    output logic          s_axi_bvalid,
    input  logic          s_axi_bready,
    input  logic [3:0]    s_axi_arid,
    input  logic [31:0]   s_axi_araddr,
    input  logic [7:0]    s_axi_arlen,
    input  logic [2:0]    s_axi_arsize,
    input  logic [1:0]    s_axi_arburst,
    input  logic [2:0]    s_axi_arprot,
    input  logic          s_axi_arvalid,
    output logic          s_axi_arready,
    input  logic          s_axi_arlock,
    input  logic [3:0]    s_axi_arcache,
    output logic [3:0]    s_axi_rid,
    output logic [255:0]  s_axi_rdata,
    output logic [1:0]    s_axi_rresp,
    output logic          s_axi_rlast,
    output logic          s_axi_rvalid,
    input  logic          s_axi_rready,

    // Native BRAM Port A -- consumer is our register file (e.g. mvp_top)
    output logic          bram_rst_a,
    output logic          bram_clk_a,
    output logic          bram_en_a,
    output logic [3:0]    bram_we_a,
    output logic [11:0]   bram_addr_a,
    output logic [31:0]   bram_wrdata_a,
    input  logic [31:0]   bram_rddata_a
);

    logic [31:0] dw_awaddr, dw_araddr;
    logic [7:0]  dw_awlen, dw_arlen;
    logic [2:0]  dw_awsize, dw_arsize;
    logic [1:0]  dw_awburst, dw_arburst, dw_bresp, dw_rresp;
    logic [0:0]  dw_awlock, dw_arlock;
    logic [3:0]  dw_awcache, dw_arcache, dw_awregion, dw_arregion, dw_awqos, dw_arqos;
    logic [2:0]  dw_awprot, dw_arprot;
    logic        dw_awvalid, dw_awready, dw_wlast, dw_wvalid, dw_wready;
    logic [31:0] dw_wdata;
    logic [3:0]  dw_wstrb;
    logic        dw_bvalid, dw_bready, dw_arvalid, dw_arready;
    logic [31:0] dw_rdata;
    logic        dw_rlast, dw_rvalid, dw_rready;

    dwidth_conv_0 u_dwidth (
        .s_axi_aclk(s_axi_aclk), .s_axi_aresetn(s_axi_aresetn),
        .s_axi_awaddr(s_axi_awaddr), .s_axi_awlen(s_axi_awlen), .s_axi_awsize(s_axi_awsize),
        .s_axi_awburst(s_axi_awburst), .s_axi_awlock(s_axi_awlock), .s_axi_awcache(s_axi_awcache),
        .s_axi_awprot(s_axi_awprot), .s_axi_awregion('0), .s_axi_awqos('0),
        .s_axi_awvalid(s_axi_awvalid), .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata), .s_axi_wstrb(s_axi_wstrb), .s_axi_wlast(s_axi_wlast),
        .s_axi_wvalid(s_axi_wvalid), .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp), .s_axi_bvalid(s_axi_bvalid), .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr), .s_axi_arlen(s_axi_arlen), .s_axi_arsize(s_axi_arsize),
        .s_axi_arburst(s_axi_arburst), .s_axi_arlock(s_axi_arlock), .s_axi_arcache(s_axi_arcache),
        .s_axi_arprot(s_axi_arprot), .s_axi_arregion('0), .s_axi_arqos('0),
        .s_axi_arvalid(s_axi_arvalid), .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata), .s_axi_rresp(s_axi_rresp), .s_axi_rlast(s_axi_rlast),
        .s_axi_rvalid(s_axi_rvalid), .s_axi_rready(s_axi_rready),
        .m_axi_awaddr(dw_awaddr), .m_axi_awlen(dw_awlen), .m_axi_awsize(dw_awsize),
        .m_axi_awburst(dw_awburst), .m_axi_awlock(dw_awlock), .m_axi_awcache(dw_awcache),
        .m_axi_awprot(dw_awprot), .m_axi_awregion(dw_awregion), .m_axi_awqos(dw_awqos),
        .m_axi_awvalid(dw_awvalid), .m_axi_awready(dw_awready),
        .m_axi_wdata(dw_wdata), .m_axi_wstrb(dw_wstrb), .m_axi_wlast(dw_wlast),
        .m_axi_wvalid(dw_wvalid), .m_axi_wready(dw_wready),
        .m_axi_bresp(dw_bresp), .m_axi_bvalid(dw_bvalid), .m_axi_bready(dw_bready),
        .m_axi_araddr(dw_araddr), .m_axi_arlen(dw_arlen), .m_axi_arsize(dw_arsize),
        .m_axi_arburst(dw_arburst), .m_axi_arlock(dw_arlock), .m_axi_arcache(dw_arcache),
        .m_axi_arprot(dw_arprot), .m_axi_arregion(dw_arregion), .m_axi_arqos(dw_arqos),
        .m_axi_arvalid(dw_arvalid), .m_axi_arready(dw_arready),
        .m_axi_rdata(dw_rdata), .m_axi_rresp(dw_rresp), .m_axi_rlast(dw_rlast),
        .m_axi_rvalid(dw_rvalid), .m_axi_rready(dw_rready)
    );

    axi_bram_ctrl_0 u_bram_ctrl (
        .s_axi_aclk(s_axi_aclk), .s_axi_aresetn(s_axi_aresetn),
        .s_axi_awaddr(dw_awaddr[11:0]), .s_axi_awlen(dw_awlen), .s_axi_awsize(dw_awsize),
        .s_axi_awburst(dw_awburst), .s_axi_awlock(dw_awlock[0]), .s_axi_awcache(dw_awcache),
        .s_axi_awprot(dw_awprot), .s_axi_awvalid(dw_awvalid), .s_axi_awready(dw_awready),
        .s_axi_wdata(dw_wdata), .s_axi_wstrb(dw_wstrb), .s_axi_wlast(dw_wlast),
        .s_axi_wvalid(dw_wvalid), .s_axi_wready(dw_wready),
        .s_axi_bresp(dw_bresp), .s_axi_bvalid(dw_bvalid), .s_axi_bready(dw_bready),
        .s_axi_araddr(dw_araddr[11:0]), .s_axi_arlen(dw_arlen), .s_axi_arsize(dw_arsize),
        .s_axi_arburst(dw_arburst), .s_axi_arlock(dw_arlock[0]), .s_axi_arcache(dw_arcache),
        .s_axi_arprot(dw_arprot), .s_axi_arvalid(dw_arvalid), .s_axi_arready(dw_arready),
        .s_axi_rdata(dw_rdata), .s_axi_rresp(dw_rresp), .s_axi_rlast(dw_rlast),
        .s_axi_rvalid(dw_rvalid), .s_axi_rready(dw_rready),
        .bram_rst_a(bram_rst_a), .bram_clk_a(bram_clk_a), .bram_en_a(bram_en_a),
        .bram_we_a(bram_we_a), .bram_addr_a(bram_addr_a),
        .bram_wrdata_a(bram_wrdata_a), .bram_rddata_a(bram_rddata_a)
    );

endmodule
