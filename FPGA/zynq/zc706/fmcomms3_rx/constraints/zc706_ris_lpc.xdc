# 25 RIS outputs: row-major out_1_1_0..out_5_5_0 to LPC LA00..LA12 P/N.
# User confirmed no existing wiring; voltage is 2.5 V, single-ended.
# J5 is FMC LPC. This connector must remain free of the RF card.

# J5 G6: FMC_LPC_LA00_CC_P
set_property -dict {PACKAGE_PIN AE13 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {out_1_1_0}]
# J5 G7: FMC_LPC_LA00_CC_N
set_property -dict {PACKAGE_PIN AF13 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {out_1_2_0}]
# J5 D8: FMC_LPC_LA01_CC_P
set_property -dict {PACKAGE_PIN AF15 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {out_1_3_0}]
# J5 D9: FMC_LPC_LA01_CC_N
set_property -dict {PACKAGE_PIN AG15 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {out_1_4_0}]
# J5 H7: FMC_LPC_LA02_P
set_property -dict {PACKAGE_PIN AE12 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {out_1_5_0}]
# J5 H8: FMC_LPC_LA02_N
set_property -dict {PACKAGE_PIN AF12 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {out_2_1_0}]
# J5 G9: FMC_LPC_LA03_P
set_property -dict {PACKAGE_PIN AG12 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {out_2_2_0}]
# J5 G10: FMC_LPC_LA03_N
set_property -dict {PACKAGE_PIN AH12 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {out_2_3_0}]
# J5 H10: FMC_LPC_LA04_P
set_property -dict {PACKAGE_PIN AJ15 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {out_2_4_0}]
# J5 H11: FMC_LPC_LA04_N
set_property -dict {PACKAGE_PIN AK15 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {out_2_5_0}]
# J5 D11: FMC_LPC_LA05_P
set_property -dict {PACKAGE_PIN AE16 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {out_3_1_0}]
# J5 D12: FMC_LPC_LA05_N
set_property -dict {PACKAGE_PIN AE15 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {out_3_2_0}]
# J5 C10: FMC_LPC_LA06_P
set_property -dict {PACKAGE_PIN AB12 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {out_3_3_0}]
# J5 C11: FMC_LPC_LA06_N
set_property -dict {PACKAGE_PIN AC12 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {out_3_4_0}]
# J5 H13: FMC_LPC_LA07_P
set_property -dict {PACKAGE_PIN AA15 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {out_3_5_0}]
# J5 H14: FMC_LPC_LA07_N
set_property -dict {PACKAGE_PIN AA14 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {out_4_1_0}]
# J5 G12: FMC_LPC_LA08_P
set_property -dict {PACKAGE_PIN AD14 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {out_4_2_0}]
# J5 G13: FMC_LPC_LA08_N
set_property -dict {PACKAGE_PIN AD13 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {out_4_3_0}]
# J5 D14: FMC_LPC_LA09_P
set_property -dict {PACKAGE_PIN AH14 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {out_4_4_0}]
# J5 D15: FMC_LPC_LA09_N
set_property -dict {PACKAGE_PIN AH13 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {out_4_5_0}]
# J5 C14: FMC_LPC_LA10_P
set_property -dict {PACKAGE_PIN AC14 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {out_5_1_0}]
# J5 C15: FMC_LPC_LA10_N
set_property -dict {PACKAGE_PIN AC13 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {out_5_2_0}]
# J5 H16: FMC_LPC_LA11_P
set_property -dict {PACKAGE_PIN AJ16 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {out_5_3_0}]
# J5 H17: FMC_LPC_LA11_N
set_property -dict {PACKAGE_PIN AK16 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {out_5_4_0}]
# J5 G15: FMC_LPC_LA12_P
set_property -dict {PACKAGE_PIN AD16 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {out_5_5_0}]

# Outputs are asynchronous control levels; there is no external sampling clock.
set_false_path -to [get_ports {out_*}]
