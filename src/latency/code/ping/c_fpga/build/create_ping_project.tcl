# Reproducible Vivado project setup for the FPGA ping responder (C):
#   source /opt/Xilinx/2026.1/Vivado/settings64.sh
#   export XILINXD_LICENSE_FILE="$HOME/.Xilinx/Xilinx.lic:/opt/Xilinx/Xilinx TEMAC.lic"
#   vivado -mode batch -source code/ping/c_fpga/build/create_ping_project.tcl
#
# Same board as ../../fpga (ALINX AXKU3, XCKU3P-2FFVB676I, 1G copper RJ-45
# -> Tri-Mode Ethernet MAC), no PCIe/XDMA and no cache -- pure RTL, no
# host software in the loop. Reuses ../../fpga/rtl/eth_mac_wrapper.sv and
# eth_test_counter.sv as-is: that wrapper is the one currently programmed
# on this board via ../../fpga's eth_loopback_top design and confirmed
# link_status=1 (1000M/full-duplex) over JTAG/VIO -- not speculative.
# IP config below (Physical_Interface, Frame_Filter) matches
# ../../fpga/build/create_loopback_project.tcl's for the same reason.

set PART "xcku3p-ffvb676-2-i"

set origin_dir     [file dirname [file dirname [file normalize [info script]]]]
set fpga_rtl_dir   [file join $origin_dir .. .. fpga rtl]
set proj_dir       [file join $origin_dir build_output]

create_project ping_responder $proj_dir -part $PART -force

set src_files [list \
    [file join $origin_dir rtl ping_pkg.sv] \
    [file join $origin_dir rtl ping_mirror.sv] \
    [file join $fpga_rtl_dir eth_mac_wrapper.sv] \
    [file join $fpga_rtl_dir eth_test_counter.sv] \
    [file join $origin_dir rtl ping_board_top.sv] \
]
add_files -norecurse $src_files
set_property file_type SystemVerilog [get_files *.sv]

# Testbench is simulation-only.
set tb_file [file join $origin_dir rtl tb_ping_mirror.sv]
remove_files -fileset sources_1 $tb_file
add_files -fileset sim_1 -norecurse $tb_file
set_property top tb_ping_mirror [get_filesets sim_1]

set_property top ping_board_top [get_filesets sources_1]
add_files -fileset constrs_1 -norecurse [file join $origin_dir build ping_board_top.xdc]
update_compile_order -fileset sources_1

# --- IP: Ethernet MAC -------------------------------------------------------
# Frame_Filter disabled: we never configure a station address via
# AXI-Lite (tied idle), so with it enabled the MAC would very plausibly
# drop everything including broadcast -- disabling gives fully
# promiscuous RX with no AXI-Lite config needed, which both this design
# and the bring-up loopback design want anyway (ping_mirror mirrors
# whatever dest MAC/IP the sender chose, it doesn't need a real
# configured identity of its own).
create_ip -name tri_mode_ethernet_mac -vendor xilinx.com -library ip -module_name eth_mac_0
set_property -dict [list \
    CONFIG.Physical_Interface {RGMII} \
    CONFIG.Frame_Filter {false} \
] [get_ips eth_mac_0]

# --- IP: 125MHz clock for the MAC, from the board's 200MHz oscillator -----
create_ip -name clk_wiz -vendor xilinx.com -library ip -module_name clk_wiz_0
set_property -dict [list \
    CONFIG.PRIM_IN_FREQ {200.000} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {125.000} \
    CONFIG.USE_LOCKED {true} \
    CONFIG.USE_RESET {true} \
] [get_ips clk_wiz_0]

# --- IP: VIO for live bring-up visibility (frame counts, link status) -----
create_ip -name vio -vendor xilinx.com -library ip -module_name vio_0
set_property -dict [list \
    CONFIG.C_NUM_PROBE_IN {5} \
    CONFIG.C_NUM_PROBE_OUT {0} \
    CONFIG.C_PROBE_IN0_WIDTH {16} \
    CONFIG.C_PROBE_IN1_WIDTH {16} \
    CONFIG.C_PROBE_IN2_WIDTH {16} \
    CONFIG.C_PROBE_IN3_WIDTH {4} \
    CONFIG.C_PROBE_IN4_WIDTH {2} \
] [get_ips vio_0]

generate_target all [get_ips]

puts "Project created at $proj_dir."
puts "Next: launch_runs synth_1, then impl_1 -to_step write_bitstream, then"
puts "program via JTAG (program_hw_devices) and read vio_0's probes to"
puts "confirm rx_frame_count/tx_frame_count move when a real ping is sent."
