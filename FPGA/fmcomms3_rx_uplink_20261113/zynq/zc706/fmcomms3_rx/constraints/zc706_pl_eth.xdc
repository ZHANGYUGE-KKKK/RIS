# Sichuan Zhenwei ZC706, J18 / U48 RTL8211FS, SGMII (not RGMII).
# Source: 1_四川真为电子_ZC706_SCH.pdf, PDF pp.7,8,43,45,46.
# The printed schematic sheet number on PDF p.46 is 49/58.
# GTX bank 111 channel 1: PHY HSIP/HSIN <- FPGA TX; HSOP/HSON -> FPGA RX.
set_property PACKAGE_PIN Y2  [get_ports pl_eth_sgmii_txp]
set_property PACKAGE_PIN Y1  [get_ports pl_eth_sgmii_txn]
set_property PACKAGE_PIN AB6 [get_ports pl_eth_sgmii_rxp]
set_property PACKAGE_PIN AB5 [get_ports pl_eth_sgmii_rxn]
# U60 Si5324 CKOUT2, through C165/C166; firmware programs 125 MHz.
set_property PACKAGE_PIN W8 [get_ports pl_eth_refclk_clk_p]
set_property PACKAGE_PIN W7 [get_ports pl_eth_refclk_clk_n]
create_clock -name pl_eth_gtrefclk -period 8.000 [get_ports pl_eth_refclk_clk_p]
# GT pins use dedicated analog I/O; do not apply an LVCMOS IOSTANDARD.
# Bank 35 is VCC1V5_PL, translated to 3.3 V by U70 TXS0108E.
set_property -dict {PACKAGE_PIN L13 IOSTANDARD LVCMOS15 SLEW SLOW DRIVE 4} [get_ports pl_eth_mdio_mdc]
set_property -dict {PACKAGE_PIN K13 IOSTANDARD LVCMOS15 SLEW SLOW DRIVE 4} [get_ports pl_eth_mdio_mdio_io]
set_property -dict {PACKAGE_PIN H14 IOSTANDARD LVCMOS15 SLEW SLOW DRIVE 4} [get_ports pl_eth_reset_n]
# Bank 11 VADJ_FPGA uses the same 2.5 V setting as the receiver FMC I/O.
# W23 -> U90 level translator -> Si5324 RST_B; GPIO56, separate from PHY reset.
set_property -dict {PACKAGE_PIN W23 IOSTANDARD LVCMOS25 SLEW SLOW DRIVE 4} [get_ports pl_eth_si5324_reset_n]
# PCS/PMA supplies its internal/GT clock and CDC constraints. These control
# ports are not a synchronous RGMII bus; no invented RGMII delays are applied.
