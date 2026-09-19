# Vivado project for the Ethernet RX-counter bring-up MVP, separate from
# the full tick-to-trade project -- smaller, faster to build, doesn't
# depend on any unfinished piece of the main design.
#
# Top is mvp_board_top.sv, which wires xdma_0 -> dwidth_conv_0 ->
# axi_bram_ctrl_0 -> mvp_top (our register file + RX logic), plus
# clk_wiz_0 deriving eth_mac_0's 125MHz gtx_clk from xdma_0's own clock.
# All IP configs below were verified against this Vivado version (2026.1)
# directly via report_property/list_property, not guessed -- several of
# the obvious property-name guesses turned out wrong for this version.
#
#   source /opt/Xilinx/2026.1/Vivado/settings64.sh
#   export XILINXD_LICENSE_FILE="$HOME/.Xilinx/Xilinx.lic:/opt/Xilinx/Xilinx TEMAC.lic"
#   vivado -mode batch -source code/fpga/build/create_mvp_project.tcl
#
# Requires the TEMAC evaluation license (see fpga/README.md) in addition
# to the base Vivado license -- eth_mac_0 will fail to generate without it.

set PART   "xcku3p-ffvb676-2-i"
set ETH_IP "tri_mode_ethernet_mac"

set origin_dir [file dirname [file dirname [file normalize [info script]]]]
set proj_dir   [file join $origin_dir mvp_build_output]

create_project tick_to_trade_mvp $proj_dir -part $PART -force

set mvp_files [list \
    [file join $origin_dir rtl market_data_pkg.sv] \
    [file join $origin_dir rtl rx_packet_counter.sv] \
    [file join $origin_dir rtl mvp_top.sv] \
    [file join $origin_dir rtl pcie_endpoint.sv] \
    [file join $origin_dir rtl reg_file_bridge.sv] \
    [file join $origin_dir rtl eth_mac_wrapper.sv] \
    [file join $origin_dir rtl mvp_board_top.sv] \
]
add_files -norecurse $mvp_files
set_property file_type SystemVerilog [get_files *.sv]

set tb_file [file join $origin_dir rtl tb_mvp.sv]
add_files -fileset sim_1 -norecurse $tb_file
set_property top tb_mvp [get_filesets sim_1]

set_property top mvp_board_top [get_filesets sources_1]
update_compile_order -fileset sources_1

add_files -fileset constrs_1 -norecurse [file join $origin_dir build mvp_board_top.xdc]

# --- IP: PCIe DMA -------------------------------------------------------
# AXI_Bridge mode (not DMA mode): we just need memory-mapped register
# access for polling, not the descriptor-based bulk DMA engine.
create_ip -name xdma -vendor xilinx.com -library ip -module_name xdma_0
set_property -dict [list \
    CONFIG.functional_mode {AXI_Bridge} \
    CONFIG.pl_link_cap_max_link_width {X8} \
    CONFIG.pl_link_cap_max_link_speed {8.0_GT/s} \
    CONFIG.axisten_freq {250} \
    CONFIG.pf0_bar0_size {128} \
    CONFIG.pf0_bar0_scale {Kilobytes} \
] [get_ips xdma_0]

# --- IP: width conversion (xdma_0's 256-bit master -> 32-bit register file) --
create_ip -name axi_dwidth_converter -vendor xilinx.com -library ip -module_name dwidth_conv_0
set_property -dict [list \
    CONFIG.SI_DATA_WIDTH {256} \
    CONFIG.MI_DATA_WIDTH {32} \
] [get_ips dwidth_conv_0]

# --- IP: register-file bridge (AXI4 -> native BRAM port on mvp_top) -----
# MEM_DEPTH is pinned to 1024 (the IP's minimum) purely to get a small,
# known bram_addr_a width (12 bits) for mvp_board_top.sv to wire up --
# our actual register file only uses the low 4 bits of it.
create_ip -name axi_bram_ctrl -vendor xilinx.com -library ip -module_name axi_bram_ctrl_0
set_property -dict [list \
    CONFIG.SINGLE_PORT_BRAM {1} \
    CONFIG.ECC_TYPE {0} \
    CONFIG.DATA_WIDTH {32} \
    CONFIG.MEM_DEPTH {1024} \
] [get_ips axi_bram_ctrl_0]

# --- IP: 125MHz reference for eth_mac_0, derived from xdma_0's axi_aclk --
create_ip -name clk_wiz -vendor xilinx.com -library ip -module_name clk_wiz_0
set_property -dict [list \
    CONFIG.PRIM_IN_FREQ {250} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {125} \
    CONFIG.USE_LOCKED {true} \
    CONFIG.USE_RESET {true} \
] [get_ips clk_wiz_0]

# --- IP: Ethernet MAC (RGMII -- confirmed by the user's cable: RJ45 both --
# ends, board's built-in copper port, no FMC/SFP+ module in use) --------
create_ip -name $ETH_IP -vendor xilinx.com -library ip -module_name eth_mac_0
set_property CONFIG.Physical_Interface {RGMII} [get_ips eth_mac_0]

generate_target all [get_ips]

puts "MVP project created at $proj_dir, top = mvp_board_top."
puts "Still needed before implementation can run: RGMII/MDIO/PHY-reset"
puts "pin constraints from the AXKU3 user manual (see fpga/README.md)."
puts "Synthesis can run now (synth_design) to catch RTL/logic errors --"
puts "implementation (place/route) cannot until the .xdc exists."
