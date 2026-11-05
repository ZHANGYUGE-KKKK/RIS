# ZC706 J5 LPC, final 50-chip daughterboard (2026-10-20).
# Source: local signal_pin_mapping.csv; vector index 0 is device/group 1.
# 2.5 V input side; clock/data are registered 100 MHz-domain outputs.
# Board bring-up uses 50 ns phases. Bound register-to-pin delay to 10 ns.
# This is a local delay budget, not board-level setup/hold sign-off.

# DATA_U01: J5 C22 / FMC_LPC_LA18_CC_P / Bank 12
set_property -dict {PACKAGE_PIN AE27 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[0]}]
# DATA_U02: J5 C23 / FMC_LPC_LA18_CC_N / Bank 12
set_property -dict {PACKAGE_PIN AF27 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[1]}]
# DATA_U03: J5 D20 / FMC_LPC_LA17_CC_P / Bank 12
set_property -dict {PACKAGE_PIN AB27 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[2]}]
# DATA_U04: J5 D21 / FMC_LPC_LA17_CC_N / Bank 12
set_property -dict {PACKAGE_PIN AC27 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[3]}]
# DATA_U05: J5 C26 / FMC_LPC_LA27_P / Bank 12
set_property -dict {PACKAGE_PIN AJ28 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[4]}]
# DATA_U06: J5 C27 / FMC_LPC_LA27_N / Bank 12
set_property -dict {PACKAGE_PIN AJ29 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[5]}]
# DATA_U07: J5 D23 / FMC_LPC_LA23_P / Bank 12
set_property -dict {PACKAGE_PIN AJ26 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[6]}]
# DATA_U08: J5 D24 / FMC_LPC_LA23_N / Bank 12
set_property -dict {PACKAGE_PIN AK26 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[7]}]
# DATA_U09: J5 G33 / FMC_LPC_LA31_P / Bank 12
set_property -dict {PACKAGE_PIN AC29 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[8]}]
# DATA_U10: J5 G34 / FMC_LPC_LA31_N / Bank 12
set_property -dict {PACKAGE_PIN AD29 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[9]}]
# DATA_U11: J5 D26 / FMC_LPC_LA26_P / Bank 12
set_property -dict {PACKAGE_PIN AJ30 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[10]}]
# DATA_U12: J5 D27 / FMC_LPC_LA26_N / Bank 12
set_property -dict {PACKAGE_PIN AK30 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[11]}]
# DATA_U13: J5 G02 / FMC_LPC_CLK1_M2C_P / Bank 12
set_property -dict {PACKAGE_PIN AC28 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[12]}]
# DATA_U14: J5 G03 / FMC_LPC_CLK1_M2C_N / Bank 12
set_property -dict {PACKAGE_PIN AD28 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[13]}]
# DATA_U15: J5 H04 / FMC_LPC_CLK0_M2C_P / Bank 10
set_property -dict {PACKAGE_PIN AG17 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[14]}]
# DATA_U16: J5 H05 / FMC_LPC_CLK0_M2C_N / Bank 10
set_property -dict {PACKAGE_PIN AG16 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[15]}]
# DATA_U17: J5 G06 / FMC_LPC_LA00_CC_P / Bank 10
set_property -dict {PACKAGE_PIN AE13 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[16]}]
# DATA_U18: J5 G07 / FMC_LPC_LA00_CC_N / Bank 10
set_property -dict {PACKAGE_PIN AF13 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[17]}]
# DATA_U19: J5 H07 / FMC_LPC_LA02_P / Bank 10
set_property -dict {PACKAGE_PIN AE12 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[18]}]
# DATA_U20: J5 H08 / FMC_LPC_LA02_N / Bank 10
set_property -dict {PACKAGE_PIN AF12 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[19]}]
# DATA_U21: J5 G09 / FMC_LPC_LA03_P / Bank 10
set_property -dict {PACKAGE_PIN AG12 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[20]}]
# DATA_U22: J5 G10 / FMC_LPC_LA03_N / Bank 10
set_property -dict {PACKAGE_PIN AH12 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[21]}]
# DATA_U23: J5 H10 / FMC_LPC_LA04_P / Bank 10
set_property -dict {PACKAGE_PIN AJ15 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[22]}]
# DATA_U24: J5 H11 / FMC_LPC_LA04_N / Bank 10
set_property -dict {PACKAGE_PIN AK15 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[23]}]
# DATA_U25: J5 G12 / FMC_LPC_LA08_P / Bank 10
set_property -dict {PACKAGE_PIN AD14 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[24]}]
# DATA_U26: J5 G13 / FMC_LPC_LA08_N / Bank 10
set_property -dict {PACKAGE_PIN AD13 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[25]}]
# DATA_U27: J5 H13 / FMC_LPC_LA07_P / Bank 10
set_property -dict {PACKAGE_PIN AA15 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[26]}]
# DATA_U28: J5 H14 / FMC_LPC_LA07_N / Bank 10
set_property -dict {PACKAGE_PIN AA14 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[27]}]
# DATA_U29: J5 G15 / FMC_LPC_LA12_P / Bank 10
set_property -dict {PACKAGE_PIN AD16 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[28]}]
# DATA_U30: J5 G16 / FMC_LPC_LA12_N / Bank 10
set_property -dict {PACKAGE_PIN AD15 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[29]}]
# DATA_U31: J5 H16 / FMC_LPC_LA11_P / Bank 10
set_property -dict {PACKAGE_PIN AJ16 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[30]}]
# DATA_U32: J5 H17 / FMC_LPC_LA11_N / Bank 10
set_property -dict {PACKAGE_PIN AK16 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[31]}]
# DATA_U33: J5 G18 / FMC_LPC_LA16_P / Bank 10
set_property -dict {PACKAGE_PIN AE18 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[32]}]
# DATA_U34: J5 G19 / FMC_LPC_LA16_N / Bank 10
set_property -dict {PACKAGE_PIN AE17 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[33]}]
# DATA_U35: J5 H19 / FMC_LPC_LA15_P / Bank 10
set_property -dict {PACKAGE_PIN AB15 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[34]}]
# DATA_U36: J5 H20 / FMC_LPC_LA15_N / Bank 10
set_property -dict {PACKAGE_PIN AB14 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[35]}]
# DATA_U37: J5 G21 / FMC_LPC_LA20_P / Bank 12
set_property -dict {PACKAGE_PIN AG26 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[36]}]
# DATA_U38: J5 G22 / FMC_LPC_LA20_N / Bank 12
set_property -dict {PACKAGE_PIN AG27 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[37]}]
# DATA_U39: J5 H22 / FMC_LPC_LA19_P / Bank 12
set_property -dict {PACKAGE_PIN AH26 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[38]}]
# DATA_U40: J5 H23 / FMC_LPC_LA19_N / Bank 12
set_property -dict {PACKAGE_PIN AH27 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[39]}]
# DATA_U41: J5 G24 / FMC_LPC_LA22_P / Bank 12
set_property -dict {PACKAGE_PIN AK27 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[40]}]
# DATA_U42: J5 G25 / FMC_LPC_LA22_N / Bank 12
set_property -dict {PACKAGE_PIN AK28 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[41]}]
# DATA_U43: J5 H25 / FMC_LPC_LA21_P / Bank 12
set_property -dict {PACKAGE_PIN AH28 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[42]}]
# DATA_U44: J5 H26 / FMC_LPC_LA21_N / Bank 12
set_property -dict {PACKAGE_PIN AH29 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[43]}]
# DATA_U45: J5 G27 / FMC_LPC_LA25_P / Bank 12
set_property -dict {PACKAGE_PIN AF29 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[44]}]
# DATA_U46: J5 G28 / FMC_LPC_LA25_N / Bank 12
set_property -dict {PACKAGE_PIN AG29 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[45]}]
# DATA_U47: J5 H28 / FMC_LPC_LA24_P / Bank 12
set_property -dict {PACKAGE_PIN AF30 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[46]}]
# DATA_U48: J5 H29 / FMC_LPC_LA24_N / Bank 12
set_property -dict {PACKAGE_PIN AG30 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[47]}]
# DATA_U49: J5 G30 / FMC_LPC_LA29_P / Bank 12
set_property -dict {PACKAGE_PIN AE25 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[48]}]
# DATA_U50: J5 G31 / FMC_LPC_LA29_N / Bank 12
set_property -dict {PACKAGE_PIN AF25 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_data[49]}]
# LATCH_CLK1: J5 G37 / FMC_LPC_LA33_N / Bank 12
set_property -dict {PACKAGE_PIN AA30 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_stcp[0]}]
# LATCH_CLK10: J5 D09 / FMC_LPC_LA01_CC_N / Bank 10
set_property -dict {PACKAGE_PIN AG15 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_stcp[9]}]
# LATCH_CLK2: J5 H35 / FMC_LPC_LA30_N / Bank 12
set_property -dict {PACKAGE_PIN AB30 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_stcp[1]}]
# LATCH_CLK3: J5 D12 / FMC_LPC_LA05_N / Bank 10
set_property -dict {PACKAGE_PIN AE15 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_stcp[2]}]
# LATCH_CLK4: J5 D18 / FMC_LPC_LA13_N / Bank 10
set_property -dict {PACKAGE_PIN AH16 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_stcp[3]}]
# LATCH_CLK5: J5 C11 / FMC_LPC_LA06_N / Bank 10
set_property -dict {PACKAGE_PIN AC12 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_stcp[4]}]
# LATCH_CLK6: J5 C15 / FMC_LPC_LA10_N / Bank 10
set_property -dict {PACKAGE_PIN AC13 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_stcp[5]}]
# LATCH_CLK7: J5 H38 / FMC_LPC_LA32_N / Bank 12
set_property -dict {PACKAGE_PIN Y27 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_stcp[6]}]
# LATCH_CLK8: J5 C19 / FMC_LPC_LA14_N / Bank 10
set_property -dict {PACKAGE_PIN AF17 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_stcp[7]}]
# LATCH_CLK9: J5 D15 / FMC_LPC_LA09_N / Bank 10
set_property -dict {PACKAGE_PIN AH13 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_stcp[8]}]
# MR_N: J5 H31 / FMC_LPC_LA28_P / Bank 12
set_property -dict {PACKAGE_PIN AD25 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_mr_n}]
# OE_SAFE_N: J5 H32 / FMC_LPC_LA28_N / Bank 12
set_property -dict {PACKAGE_PIN AE26 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_oe_n}]
# SHIFT_CLK1: J5 H34 / FMC_LPC_LA30_P / Bank 12
set_property -dict {PACKAGE_PIN AB29 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_shcp[0]}]
# SHIFT_CLK10: J5 D08 / FMC_LPC_LA01_CC_P / Bank 10
set_property -dict {PACKAGE_PIN AF15 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_shcp[9]}]
# SHIFT_CLK2: J5 H37 / FMC_LPC_LA32_P / Bank 12
set_property -dict {PACKAGE_PIN Y26 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_shcp[1]}]
# SHIFT_CLK3: J5 D14 / FMC_LPC_LA09_P / Bank 10
set_property -dict {PACKAGE_PIN AH14 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_shcp[2]}]
# SHIFT_CLK4: J5 D11 / FMC_LPC_LA05_P / Bank 10
set_property -dict {PACKAGE_PIN AE16 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_shcp[3]}]
# SHIFT_CLK5: J5 D17 / FMC_LPC_LA13_P / Bank 10
set_property -dict {PACKAGE_PIN AH17 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_shcp[4]}]
# SHIFT_CLK6: J5 C10 / FMC_LPC_LA06_P / Bank 10
set_property -dict {PACKAGE_PIN AB12 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_shcp[5]}]
# SHIFT_CLK7: J5 G36 / FMC_LPC_LA33_P / Bank 12
set_property -dict {PACKAGE_PIN Y30 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_shcp[6]}]
# SHIFT_CLK8: J5 C18 / FMC_LPC_LA14_P / Bank 10
set_property -dict {PACKAGE_PIN AF18 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_shcp[7]}]
# SHIFT_CLK9: J5 C14 / FMC_LPC_LA10_P / Bank 10
set_property -dict {PACKAGE_PIN AC14 IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW} [get_ports {ris_shcp[8]}]

# Use the launch CLOCK, not register Q pins, to preserve normal internal timing.
set_max_delay 10.000 -datapath_only -from [get_clocks clk_fpga_0] -to [get_ports {ris_data[*] ris_shcp[*] ris_stcp[*] ris_mr_n ris_oe_n}]
