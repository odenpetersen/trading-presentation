# Smallest possible Vivado project to prove real hardware works:
# heartbeat_top, a free-running counter over PCIe/XDMA, no Ethernet MAC IP
# at all -- sidesteps both current blockers (TEMAC license, unknown PHY
# pinout). See fpga/rtl/heartbeat_reg.sv for why this exists.
#
#   source /opt/Xilinx/2026.1/Vivado/settings64.sh
#   vivado -mode batch -source code/fpga/build/create_heartbeat_project.tcl

set PART "xcku3p-ffvb676-2-i"

set origin_dir [file dirname [file dirname [file normalize [info script]]]]
set proj_dir   [file join $origin_dir heartbeat_build_output]

create_project tick_to_trade_heartbeat $proj_dir -part $PART -force

set hb_files [list \
    [file join $origin_dir rtl heartbeat_reg.sv] \
    [file join $origin_dir rtl heartbeat_top.sv] \
]
add_files -norecurse $hb_files
set_property file_type SystemVerilog [get_files *.sv]

set tb_file [file join $origin_dir rtl tb_heartbeat.sv]
add_files -fileset sim_1 -norecurse $tb_file
set_property top tb_heartbeat [get_filesets sim_1]

set_property top heartbeat_top [get_filesets sources_1]
update_compile_order -fileset sources_1

# --- IP: PCIe DMA (config verified against this Vivado version directly) --
create_ip -name xdma -vendor xilinx.com -library ip -module_name xdma_0
set_property -dict [list \
    CONFIG.functional_mode {AXI_Bridge} \
    CONFIG.pl_link_cap_max_link_width {X8} \
    CONFIG.pl_link_cap_max_link_speed {8.0_GT/s} \
    CONFIG.axisten_freq {250} \
    CONFIG.pf0_bar0_size {128} \
    CONFIG.pf0_bar0_scale {Kilobytes} \
] [get_ips xdma_0]

# --- IP: register bridge (AXI4 -> native BRAM port on heartbeat_reg) ------
create_ip -name axi_bram_ctrl -vendor xilinx.com -library ip -module_name axi_bram_ctrl_0
set_property -dict [list \
    CONFIG.SINGLE_PORT_BRAM {1} \
    CONFIG.ECC_TYPE {0} \
    CONFIG.DATA_WIDTH {32} \
] [get_ips axi_bram_ctrl_0]

generate_target all [get_ips]

puts "Heartbeat project created at $proj_dir."
puts "Next: write heartbeat_board_top.sv wiring xdma_0's AXI4 master ->"
puts "axi_bram_ctrl_0 -> heartbeat_top's Port A, using xdma_0's own"
puts "output clock (no external clock pin needed -- comes from the PCIe"
puts "refclk via xdma_0's transceiver, already routed by the board's"
puts "PCIe edge connector). Then constraints (just the PCIe pins, which"
puts "board files or the AXKU3 manual should cover), then synthesize."
