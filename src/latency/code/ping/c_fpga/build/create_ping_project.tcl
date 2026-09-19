# Reproducible Vivado project setup for the FPGA ping responder (C):
#   source /opt/Xilinx/2026.1/Vivado/settings64.sh
#   vivado -mode batch -source code/ping/c_fpga/build/create_ping_project.tcl
#
# Same board as ../../fpga (ALINX AXKU3, XCKU3P-2FFVB676I, 1G copper RJ-45
# -> Tri-Mode Ethernet MAC), but no PCIe/XDMA and no cache -- this design
# is pure RTL, no host software in the loop at all.

set PART "xcku3p-ffvb676-2-i"

set origin_dir [file dirname [file dirname [file normalize [info script]]]]
set proj_dir   [file join $origin_dir build_output]

create_project ping_responder $proj_dir -part $PART -force

add_files -norecurse [glob [file join $origin_dir rtl *.sv]]
set_property file_type SystemVerilog [get_files *.sv]

# Testbench is simulation-only.
set tb_file [file join $origin_dir rtl tb_ping_mirror.sv]
remove_files -fileset sources_1 $tb_file
add_files -fileset sim_1 -norecurse $tb_file
set_property top tb_ping_mirror [get_filesets sim_1]

set_property top ping_board_top [get_filesets sources_1]
add_files -fileset constrs_1 -norecurse [file join $origin_dir build ping_board_top.xdc]
update_compile_order -fileset sources_1

# --- IP: Ethernet MAC ------------------------------------------------------
create_ip -name tri_mode_ethernet_mac -vendor xilinx.com -library ip -module_name eth_mac_0
# TODO: customize for RGMII PHY interface (this board has no internal
# delay strapping -- see build/ping_board_top.xdc's header comment) via
# the IP customization GUI. Same known gap as ../../fpga's eth_mac_0.

# --- IP: 125MHz clock for the MAC, from the board's 200MHz oscillator -----
create_ip -name clk_wiz -vendor xilinx.com -library ip -module_name clk_wiz_0
set_property -dict [list \
    CONFIG.PRIM_IN_FREQ {200.000} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {125.000} \
    CONFIG.USE_LOCKED {true} \
    CONFIG.USE_RESET {true} \
] [get_ips clk_wiz_0]

generate_target all [get_ips]

puts "Project created at $proj_dir."
puts "Next: simulate first (xvlog -sv rtl/*.sv && xelab tb_ping_mirror -s tb && xsim tb -R"
puts "-- already passing standalone, see rtl/tb_ping_mirror.sv), then finish"
puts "eth_mac_0's RGMII customization and run synthesis/implementation."
