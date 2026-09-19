# Pin constraints for the AXKU3, sourced directly from the ALINX AXKU3
# User Manual REV1.1: Table 13 (Ethernet PHY Pin Assignment, p.26) and
# Table 11 (PCIe x8 Interface FPGA Pin Assignments, p.24-25). Not guessed.
#
# PHY: JL21221D. Per the manual's Table 12 (p.25), RXD1_TXDLY and
# RXD0_RXDLY are strapped to "Delay" -- the PHY itself adds the RGMII
# 2ns TX/RX clock delay, so eth_mac_0's RGMII interface must be configured
# for NO additional internal delay on the FPGA side (this is the
# "rgmii-id"-equivalent PHY-side-delay mode familiar from other RGMII
# designs) -- double-check this against eth_mac_0's RGMII delay IP
# customization option before implementation.
#
# IOSTANDARD is set to LVCMOS18 as the common default for this class of
# board -- not explicitly stated in the manual for these specific pins.
# If wrong, Vivado's DRC will flag a VCCO/IOSTANDARD mismatch against the
# bank's actual supply during implementation -- treat any such DRC error
# as the signal to revisit this, not silent.

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

## --- 200MHz IDELAYCTRL reference (Table 6, p.14: B84_L5_P/N) -----------
# IOSTANDARD not explicitly stated for this pin in the manual. First try
# (LVDS) failed DRC: Bank 84 is High Density, which doesn't support LVDS
# at all. DIFF_SSTL12 chosen because this same oscillator (schematic
# Figure 10, p.13) also drives DDR4_CLKREF_P/N -- DDR4 signals at 1.2V
# use SSTL12, a standard HD banks do support.
set_property PACKAGE_PIN AC13 [get_ports clk200_p]
set_property PACKAGE_PIN AC14 [get_ports clk200_n]
set_property IOSTANDARD DIFF_SSTL12 [get_ports clk200_p]
set_property IOSTANDARD DIFF_SSTL12 [get_ports clk200_n]
create_clock -period 5.000 -name clk200 [get_ports clk200_p]

# Both flagged by place_design as "sub-optimal clock-capable IO / BUFG
# pairing" -- exact override syntax as suggested by that error message,
# not guessed. Acceptable here: clk200 only calibrates IDELAYCTRL (no
# tight timing requirement), and rgmii_rxc is sourced from the PHY at a
# fixed 125MHz with margin. Revisit if timing analysis says otherwise.
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets u_eth/u_clk200_ibuf/O]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets u_eth/u_eth_mac/inst/rgmii_interface/rgmii_rxc_ibuf_i/O]

## --- PCIe x8 (Table 11) -------------------------------------------------
# Lane order confirmed 1:1 from the manual (PCIE_RXn_P/N -> pci_exp_rxp/n[n]).
set_property PACKAGE_PIN Y2  [get_ports {pci_exp_rxp[0]}]
set_property PACKAGE_PIN Y1  [get_ports {pci_exp_rxn[0]}]
set_property PACKAGE_PIN V2  [get_ports {pci_exp_rxp[1]}]
set_property PACKAGE_PIN V1  [get_ports {pci_exp_rxn[1]}]
set_property PACKAGE_PIN T2  [get_ports {pci_exp_rxp[2]}]
set_property PACKAGE_PIN T1  [get_ports {pci_exp_rxn[2]}]
set_property PACKAGE_PIN P2  [get_ports {pci_exp_rxp[3]}]
set_property PACKAGE_PIN P1  [get_ports {pci_exp_rxn[3]}]
set_property PACKAGE_PIN AB2 [get_ports {pci_exp_rxp[4]}]
set_property PACKAGE_PIN AB1 [get_ports {pci_exp_rxn[4]}]
set_property PACKAGE_PIN AD2 [get_ports {pci_exp_rxp[5]}]
set_property PACKAGE_PIN AD1 [get_ports {pci_exp_rxn[5]}]
set_property PACKAGE_PIN AE4 [get_ports {pci_exp_rxp[6]}]
set_property PACKAGE_PIN AE3 [get_ports {pci_exp_rxn[6]}]
set_property PACKAGE_PIN AF2 [get_ports {pci_exp_rxp[7]}]
set_property PACKAGE_PIN AF1 [get_ports {pci_exp_rxn[7]}]

set_property PACKAGE_PIN AA5 [get_ports {pci_exp_txp[0]}]
set_property PACKAGE_PIN AA4 [get_ports {pci_exp_txn[0]}]
set_property PACKAGE_PIN W5  [get_ports {pci_exp_txp[1]}]
set_property PACKAGE_PIN W4  [get_ports {pci_exp_txn[1]}]
set_property PACKAGE_PIN U5  [get_ports {pci_exp_txp[2]}]
set_property PACKAGE_PIN U4  [get_ports {pci_exp_txn[2]}]
set_property PACKAGE_PIN R5  [get_ports {pci_exp_txp[3]}]
set_property PACKAGE_PIN R4  [get_ports {pci_exp_txn[3]}]
set_property PACKAGE_PIN AC5 [get_ports {pci_exp_txp[4]}]
set_property PACKAGE_PIN AC4 [get_ports {pci_exp_txn[4]}]
set_property PACKAGE_PIN AD7 [get_ports {pci_exp_txp[5]}]
set_property PACKAGE_PIN AD6 [get_ports {pci_exp_txn[5]}]
set_property PACKAGE_PIN AE9 [get_ports {pci_exp_txp[6]}]
set_property PACKAGE_PIN AE8 [get_ports {pci_exp_txn[6]}]
set_property PACKAGE_PIN AF7 [get_ports {pci_exp_txp[7]}]
set_property PACKAGE_PIN AF6 [get_ports {pci_exp_txn[7]}]

set_property PACKAGE_PIN V7 [get_ports sys_clk_p]
set_property PACKAGE_PIN V6 [get_ports sys_clk_n]
create_clock -period 10.000 -name sys_clk [get_ports sys_clk_p]

set_property PACKAGE_PIN T19 [get_ports sys_rst_n]
set_property IOSTANDARD LVCMOS18 [get_ports sys_rst_n]
