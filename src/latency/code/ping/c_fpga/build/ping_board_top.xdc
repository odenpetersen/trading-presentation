# Pin constraints for the ALINX AXKU3, reusing the exact RGMII + clk200
# pins already sourced from the AXKU3 User Manual REV1.1 in
# ../../fpga/build/mvp_board_top.xdc (Table 13 p.26, Table 6 p.14) --
# see that file's header comment for the RGMII delay-mode caveat, which
# applies here unchanged. No PCIe pins needed -- this design doesn't use it.

## --- Ethernet PHY (JL21221D), RGMII -----------------------------------
set_property PACKAGE_PIN N26 [get_ports mdc]
set_property PACKAGE_PIN U19 [get_ports mdio]
set_property PACKAGE_PIN N22 [get_ports phy_rst_n]
set_property PACKAGE_PIN U21 [get_ports rgmii_rxc]
set_property PACKAGE_PIN R23 [get_ports rgmii_rx_ctl]
set_property PACKAGE_PIN V19 [get_ports {rgmii_rxd[0]}]
set_property PACKAGE_PIN P20 [get_ports {rgmii_rxd[1]}]
set_property PACKAGE_PIN P21 [get_ports {rgmii_rxd[2]}]
set_property PACKAGE_PIN R22 [get_ports {rgmii_rxd[3]}]
set_property PACKAGE_PIN R25 [get_ports rgmii_txc]
set_property PACKAGE_PIN R26 [get_ports rgmii_tx_ctl]
set_property PACKAGE_PIN V21 [get_ports {rgmii_txd[0]}]
set_property PACKAGE_PIN V22 [get_ports {rgmii_txd[1]}]
set_property PACKAGE_PIN N19 [get_ports {rgmii_txd[2]}]
set_property PACKAGE_PIN P19 [get_ports {rgmii_txd[3]}]

set_property IOSTANDARD LVCMOS18 [get_ports mdc]
set_property IOSTANDARD LVCMOS18 [get_ports mdio]
set_property IOSTANDARD LVCMOS18 [get_ports phy_rst_n]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_rxc]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_rx_ctl]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_rxd[*]}]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_txc]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_tx_ctl]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_txd[*]}]

## --- 200MHz oscillator: IDELAYCTRL reference AND clk_wiz_0 input -------
# (Table 6, p.14: B84_L5_P/N.) DIFF_SSTL12 because Bank 84 is High
# Density (no LVDS support) and this oscillator also drives DDR4_CLKREF.
set_property PACKAGE_PIN AC13 [get_ports clk200_p]
set_property PACKAGE_PIN AC14 [get_ports clk200_n]
set_property IOSTANDARD DIFF_SSTL12 [get_ports clk200_p]
set_property IOSTANDARD DIFF_SSTL12 [get_ports clk200_n]
create_clock -period 5.000 -name clk200 [get_ports clk200_p]

set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets u_eth/u_clk200_ibuf/O]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets u_eth/u_eth_mac/inst/rgmii_interface/rgmii_rxc_ibuf_i/O]
