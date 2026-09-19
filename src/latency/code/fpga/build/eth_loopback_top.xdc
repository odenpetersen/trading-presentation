# Pin constraints for the AXKU3, sourced directly from the ALINX AXKU3
# User Manual REV1.1: Table 13 (Ethernet PHY Pin Assignment, p.26). Not
# guessed. No PCIe pins in this version -- eth_loopback_top has no PCIe
# interface at all, see fpga/README.md for why.
#
# PHY: JL21221D. Per the manual's Table 12 (p.25), RXD1_TXDLY and
# RXD0_RXDLY are strapped to "Delay" -- the PHY itself adds the RGMII
# 2ns TX/RX clock delay, so eth_mac_0's RGMII interface must be configured
# for NO additional internal delay on the FPGA side.
#
# IOSTANDARD is LVCMOS18 -- not explicitly stated in the manual for these
# pins, but confirmed correct by DRC during the earlier PCIe-based build
# (Bank containing these pins is High Performance, doesn't support
# LVCMOS33; LVCMOS18 passed).

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

## --- 200MHz IDELAYCTRL + gtx_clk reference (Table 6, p.14: B84_L5_P/N) --
# DIFF_SSTL12: Bank is High Density (no LVDS support); this same
# oscillator also drives DDR4_CLKREF_P/N (schematic Figure 10, p.13),
# DDR4 signals at 1.2V use SSTL12, a standard HD banks support.
set_property PACKAGE_PIN AC13 [get_ports clk200_p]
set_property PACKAGE_PIN AC14 [get_ports clk200_n]
set_property IOSTANDARD DIFF_SSTL12 [get_ports clk200_p]
set_property IOSTANDARD DIFF_SSTL12 [get_ports clk200_n]
create_clock -period 5.000 -name clk200 [get_ports clk200_p]

# Both flagged by place_design as "sub-optimal clock-capable IO / BUFG
# pairing" in the earlier PCIe-based build -- same instance paths apply
# here since eth_mac_wrapper is still instantiated as u_eth.
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets u_eth/u_clk200_ibuf/O]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets u_eth/u_eth_mac/inst/rgmii_interface/rgmii_rxc_ibuf_i/O]
