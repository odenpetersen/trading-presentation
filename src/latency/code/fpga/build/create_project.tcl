# Reproducible Vivado project setup for the tick-to-trade design.
# Run from Vivado's Tcl console, or headless:
#   source /opt/Xilinx/2026.1/Vivado/settings64.sh
#   vivado -mode batch -source code/fpga/build/create_project.tcl
#
# PART/ETH_IP confirmed for the actual hardware: ALINX AXKU3 board
# (Xilinx Kintex UltraScale+ XCKU3P-2FFVB676I, JTAG IDCODE 04A63093), with
# its only network interface being the built-in 10/100/1000M copper RJ-45
# -- confirmed by the cable itself (RJ45 both ends, no FMC/SFP+ module in
# use). If a faster interface is added later via the FMC connector, update
# both of these (and DATA_WIDTH in market_data_pkg.sv).

set PART   "xcku3p-ffvb676-2-i"
set ETH_IP "tri_mode_ethernet_mac"   ;# cmac_usplus (100G) | xxv_ethernet (10G/25G) | tri_mode_ethernet_mac (1G, this board)

set origin_dir [file dirname [file dirname [file normalize [info script]]]]
set proj_dir   [file join $origin_dir build_output]

create_project tick_to_trade $proj_dir -part $PART -force

add_files -norecurse [glob [file join $origin_dir rtl *.sv]]
set_property file_type SystemVerilog [get_files *.sv]

# Testbench is simulation-only, not a synthesis source.
set tb_file [file join $origin_dir rtl tb_tick_to_trade.sv]
remove_files -fileset sources_1 $tb_file
add_files -fileset sim_1 -norecurse $tb_file
set_property top tb_tick_to_trade [get_filesets sim_1]

set_property top tick_to_trade_top [get_filesets sources_1]
update_compile_order -fileset sources_1

# --- IP: PCIe DMA ---------------------------------------------------------
create_ip -name xdma -vendor xilinx.com -library ip -module_name xdma_0
# TODO: set_property -dict [list CONFIG.pl_link_cap_max_lanes {...} CONFIG.pl_link_cap_max_link_speed {...} CONFIG.axi_data_width {...}] [get_ips xdma_0]
# and add a BAR mapping wide enough for CACHE_DEPTH * (LINE_WIDTH_BITS/8) bytes.

# --- IP: cache refresh bridge (AXI4 -> native BRAM port on td_cache_bram) --
create_ip -name axi_bram_ctrl -vendor xilinx.com -library ip -module_name axi_bram_ctrl_0
set_property -dict [list CONFIG.SINGLE_PORT_BRAM {1} CONFIG.ECC_TYPE {0}] [get_ips axi_bram_ctrl_0]
# NOTE: leave "Fill Memory"/BMG generation disabled where possible -- we're
# wiring its native BRAM port straight to td_cache_bram's Port A ourselves,
# not to a Block Memory Generator instance.

# --- IP: Ethernet MAC/subsystem -------------------------------------------
switch $ETH_IP {
    cmac_usplus {
        create_ip -name cmac_usplus -vendor xilinx.com -library ip -module_name eth_mac_0
    }
    xxv_ethernet {
        create_ip -name xxv_ethernet -vendor xilinx.com -library ip -module_name eth_mac_0
    }
    tri_mode_ethernet_mac {
        create_ip -name tri_mode_ethernet_mac -vendor xilinx.com -library ip -module_name eth_mac_0
    }
    default { error "Unknown ETH_IP: $ETH_IP" }
}
# TODO: customize eth_mac_0 for your line rate / lane count / GT locations
# via the IP customization GUI (Vivado > IP Sources > eth_mac_0 > double-click),
# then check DATA_WIDTH in market_data_pkg.sv matches its AXI4-Stream width.

generate_target all [get_ips]

puts "Project created at $proj_dir."
puts "Next: write a plain-RTL top wrapper instantiating xdma_0, axi_bram_ctrl_0,"
puts "eth_mac_0 and tick_to_trade_top, wiring axi_bram_ctrl_0's BRAM_PORTA"
puts "signals to tick_to_trade_top's Port A and eth_mac_0's AXI4-Stream to"
puts "tick_to_trade_top's s_axis/m_axis. Add it with add_files and set it as top."
