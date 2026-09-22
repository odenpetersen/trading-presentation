# Ethernet RX/TX loopback bring-up test -- no PCIe at all. Proves the MAC
# and RGMII interface actually work using only JTAG (programming + a VIO
# dashboard for live counter visibility), sidestepping the whole
# flash/reboot-survival problem PCIe enumeration ran into. See
# fpga/README.md for why this exists.
#
#   source /opt/Xilinx/2026.1/Vivado/settings64.sh
#   export XILINXD_LICENSE_FILE="$HOME/.Xilinx/Xilinx.lic:/opt/Xilinx/Xilinx TEMAC.lic"
#   vivado -mode batch -source code/fpga/build/create_loopback_project.tcl
#
# Requires the TEMAC evaluation license (see fpga/README.md) for eth_mac_0.

set PART "xcku3p-ffvb676-2-i"

set origin_dir [file dirname [file dirname [file normalize [info script]]]]
set proj_dir   [file join $origin_dir loopback_build_output]

create_project tick_to_trade_loopback $proj_dir -part $PART -force

set src_files [list \
    [file join $origin_dir rtl eth_mac_wrapper.sv] \
    [file join $origin_dir rtl eth_test_counter.sv] \
    [file join $origin_dir rtl eth_loopback_top.sv] \
]
add_files -norecurse $src_files
set_property file_type SystemVerilog [get_files *.sv]
set_property top eth_loopback_top [get_filesets sources_1]
update_compile_order -fileset sources_1

add_files -fileset constrs_1 -norecurse [file join $origin_dir build eth_loopback_top.xdc]

# --- IP: Ethernet MAC (RGMII) -- same config as the PCIe build, except
# Frame_Filter disabled: it defaults to true, is a hardware MAC-address
# filter, and we never configure any address via AXI-Lite (that
# interface is tied idle) -- with it enabled and no addresses configured,
# it very plausibly drops everything including broadcast. Disabling it
# gives fully promiscuous operation with no AXI-Lite config needed at all,
# which is what a bring-up test wants anyway.
create_ip -name tri_mode_ethernet_mac -vendor xilinx.com -library ip -module_name eth_mac_0
set_property -dict [list \
    CONFIG.Physical_Interface {RGMII} \
    CONFIG.Frame_Filter {false} \
] [get_ips eth_mac_0]

# --- IP: 125MHz from the 200MHz oscillator (no XDMA clock available) ----
create_ip -name clk_wiz -vendor xilinx.com -library ip -module_name clk_wiz_0
set_property -dict [list \
    CONFIG.PRIM_IN_FREQ {200} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {125} \
    CONFIG.USE_LOCKED {true} \
    CONFIG.USE_RESET {true} \
] [get_ips clk_wiz_0]

# --- IP: async AXI4-Stream FIFO for the RX(clk_rx) -> TX(clk_tx) loopback -
create_ip -name axis_data_fifo -vendor xilinx.com -library ip -module_name axis_fifo_0
set_property -dict [list \
    CONFIG.IS_ACLK_ASYNC {1} \
    CONFIG.HAS_TLAST {1} \
    CONFIG.TUSER_WIDTH {1} \
    CONFIG.TDATA_NUM_BYTES {1} \
    CONFIG.M_CLKIF.FREQ_HZ {125000000} \
    CONFIG.S_CLKIF.FREQ_HZ {125000000} \
] [get_ips axis_fifo_0]

# --- IP: VIO for live frame-count/last-length/link-status readback ------
create_ip -name vio -vendor xilinx.com -library ip -module_name vio_0
set_property -dict [list \
    CONFIG.C_NUM_PROBE_IN {4} \
    CONFIG.C_NUM_PROBE_OUT {0} \
    CONFIG.C_PROBE_IN0_WIDTH {16} \
    CONFIG.C_PROBE_IN1_WIDTH {16} \
    CONFIG.C_PROBE_IN2_WIDTH {4} \
    CONFIG.C_PROBE_IN3_WIDTH {2} \
] [get_ips vio_0]

# --- IP: ILA for direct evidence of RX AXI4-Stream activity -------------
create_ip -name ila -vendor xilinx.com -library ip -module_name ila_0
set_property -dict [list \
    CONFIG.C_NUM_OF_PROBES {5} \
    CONFIG.C_DATA_DEPTH {4096} \
    CONFIG.C_PROBE0_WIDTH {1} \
    CONFIG.C_PROBE1_WIDTH {1} \
    CONFIG.C_PROBE2_WIDTH {1} \
    CONFIG.C_PROBE3_WIDTH {1} \
    CONFIG.C_PROBE4_WIDTH {8} \
    CONFIG.C_TRIGIN_EN {false} \
    CONFIG.C_TRIGOUT_EN {false} \
] [get_ips ila_0]

generate_target all [get_ips]

puts "Loopback project created at $proj_dir, top = eth_loopback_top."
puts "No PCIe -- just program via JTAG (program_hw_devices, volatile SRAM"
puts "is fine, no reboot needed) and open the VIO dashboard in Hardware"
puts "Manager to watch probe_in0 (frame_count) / probe_in1 (last_frame_len)."
puts "Ping the board's MAC/IP from another machine to test RX+TX together."
