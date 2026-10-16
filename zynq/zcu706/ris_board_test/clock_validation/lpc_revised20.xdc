# REQUIRES daughterboard rewire: CLK1 to G36/G37; CLK3 to H37/H38.
# Remove H38 VADJ connection. Correct VADJ/GND pin assignments before hardware use.
set_property PACKAGE_PIN H9 [get_ports sysclk_p]
set_property PACKAGE_PIN G9 [get_ports sysclk_n]
set_property IOSTANDARD LVDS [get_ports {sysclk_p sysclk_n}]
create_clock -name sysclk -period 5.000 [get_ports sysclk_p]
# G37: FMC_LPC_LA33_N; IO_L1N_T0_12_AA30
set_property PACKAGE_PIN AA30 [get_ports LATCH_CLK1]
set_property IOSTANDARD LVCMOS25 [get_ports LATCH_CLK1]
set_property DRIVE 8 [get_ports LATCH_CLK1]
set_property SLEW SLOW [get_ports LATCH_CLK1]
# G36: FMC_LPC_LA33_P; IO_L1P_T0_12_Y30
set_property PACKAGE_PIN Y30 [get_ports SHIFT_CLK1]
set_property IOSTANDARD LVCMOS25 [get_ports SHIFT_CLK1]
set_property DRIVE 8 [get_ports SHIFT_CLK1]
set_property SLEW SLOW [get_ports SHIFT_CLK1]
# H35: FMC_LPC_LA30_N; IO_L2N_T0_12_AB30
set_property PACKAGE_PIN AB30 [get_ports LATCH_CLK2]
set_property IOSTANDARD LVCMOS25 [get_ports LATCH_CLK2]
set_property DRIVE 8 [get_ports LATCH_CLK2]
set_property SLEW SLOW [get_ports LATCH_CLK2]
# H34: FMC_LPC_LA30_P; IO_L2P_T0_12_AB29
set_property PACKAGE_PIN AB29 [get_ports SHIFT_CLK2]
set_property IOSTANDARD LVCMOS25 [get_ports SHIFT_CLK2]
set_property DRIVE 8 [get_ports SHIFT_CLK2]
set_property SLEW SLOW [get_ports SHIFT_CLK2]
# H38: FMC_LPC_LA32_N; IO_L3N_T0_DQS_12_Y27
set_property PACKAGE_PIN Y27 [get_ports LATCH_CLK3]
set_property IOSTANDARD LVCMOS25 [get_ports LATCH_CLK3]
set_property DRIVE 8 [get_ports LATCH_CLK3]
set_property SLEW SLOW [get_ports LATCH_CLK3]
# H37: FMC_LPC_LA32_P; IO_L3P_T0_DQS_12_Y26
set_property PACKAGE_PIN Y26 [get_ports SHIFT_CLK3]
set_property IOSTANDARD LVCMOS25 [get_ports SHIFT_CLK3]
set_property DRIVE 8 [get_ports SHIFT_CLK3]
set_property SLEW SLOW [get_ports SHIFT_CLK3]
# D9: FMC_LPC_LA01_CC_N; IO_L14N_T2_SRCC_10_AG15
set_property PACKAGE_PIN AG15 [get_ports LATCH_CLK4]
set_property IOSTANDARD LVCMOS25 [get_ports LATCH_CLK4]
set_property DRIVE 8 [get_ports LATCH_CLK4]
set_property SLEW SLOW [get_ports LATCH_CLK4]
# D8: FMC_LPC_LA01_CC_P; IO_L14P_T2_SRCC_10_AF15
set_property PACKAGE_PIN AF15 [get_ports SHIFT_CLK4]
set_property IOSTANDARD LVCMOS25 [get_ports SHIFT_CLK4]
set_property DRIVE 8 [get_ports SHIFT_CLK4]
set_property SLEW SLOW [get_ports SHIFT_CLK4]
# C11: FMC_LPC_LA06_N; IO_L21N_T3_DQS_10_AC12
set_property PACKAGE_PIN AC12 [get_ports LATCH_CLK5]
set_property IOSTANDARD LVCMOS25 [get_ports LATCH_CLK5]
set_property DRIVE 8 [get_ports LATCH_CLK5]
set_property SLEW SLOW [get_ports LATCH_CLK5]
# C10: FMC_LPC_LA06_P; IO_L21P_T3_DQS_10_AB12
set_property PACKAGE_PIN AB12 [get_ports SHIFT_CLK5]
set_property IOSTANDARD LVCMOS25 [get_ports SHIFT_CLK5]
set_property DRIVE 8 [get_ports SHIFT_CLK5]
set_property SLEW SLOW [get_ports SHIFT_CLK5]
# D12: FMC_LPC_LA05_N; IO_L16N_T2_10_AE15
set_property PACKAGE_PIN AE15 [get_ports LATCH_CLK6]
set_property IOSTANDARD LVCMOS25 [get_ports LATCH_CLK6]
set_property DRIVE 8 [get_ports LATCH_CLK6]
set_property SLEW SLOW [get_ports LATCH_CLK6]
# D11: FMC_LPC_LA05_P; IO_L16P_T2_10_AE16
set_property PACKAGE_PIN AE16 [get_ports SHIFT_CLK6]
set_property IOSTANDARD LVCMOS25 [get_ports SHIFT_CLK6]
set_property DRIVE 8 [get_ports SHIFT_CLK6]
set_property SLEW SLOW [get_ports SHIFT_CLK6]
# C15: FMC_LPC_LA10_N; IO_L19N_T3_VREF_10_AC13
set_property PACKAGE_PIN AC13 [get_ports LATCH_CLK7]
set_property IOSTANDARD LVCMOS25 [get_ports LATCH_CLK7]
set_property DRIVE 8 [get_ports LATCH_CLK7]
set_property SLEW SLOW [get_ports LATCH_CLK7]
# C14: FMC_LPC_LA10_P; IO_L19P_T3_10_AC14
set_property PACKAGE_PIN AC14 [get_ports SHIFT_CLK7]
set_property IOSTANDARD LVCMOS25 [get_ports SHIFT_CLK7]
set_property DRIVE 8 [get_ports SHIFT_CLK7]
set_property SLEW SLOW [get_ports SHIFT_CLK7]
# D15: FMC_LPC_LA09_N; IO_L8N_T1_10_AH13
set_property PACKAGE_PIN AH13 [get_ports LATCH_CLK8]
set_property IOSTANDARD LVCMOS25 [get_ports LATCH_CLK8]
set_property DRIVE 8 [get_ports LATCH_CLK8]
set_property SLEW SLOW [get_ports LATCH_CLK8]
# D14: FMC_LPC_LA09_P; IO_L8P_T1_10_AH14
set_property PACKAGE_PIN AH14 [get_ports SHIFT_CLK8]
set_property IOSTANDARD LVCMOS25 [get_ports SHIFT_CLK8]
set_property DRIVE 8 [get_ports SHIFT_CLK8]
set_property SLEW SLOW [get_ports SHIFT_CLK8]
# C19: FMC_LPC_LA14_N; IO_L15N_T2_DQS_10_AF17
set_property PACKAGE_PIN AF17 [get_ports LATCH_CLK9]
set_property IOSTANDARD LVCMOS25 [get_ports LATCH_CLK9]
set_property DRIVE 8 [get_ports LATCH_CLK9]
set_property SLEW SLOW [get_ports LATCH_CLK9]
# C18: FMC_LPC_LA14_P; IO_L15P_T2_DQS_10_AF18
set_property PACKAGE_PIN AF18 [get_ports SHIFT_CLK9]
set_property IOSTANDARD LVCMOS25 [get_ports SHIFT_CLK9]
set_property DRIVE 8 [get_ports SHIFT_CLK9]
set_property SLEW SLOW [get_ports SHIFT_CLK9]
# D18: FMC_LPC_LA13_N; IO_L6N_T0_VREF_10_AH16
set_property PACKAGE_PIN AH16 [get_ports LATCH_CLK10]
set_property IOSTANDARD LVCMOS25 [get_ports LATCH_CLK10]
set_property DRIVE 8 [get_ports LATCH_CLK10]
set_property SLEW SLOW [get_ports LATCH_CLK10]
# D17: FMC_LPC_LA13_P; IO_L6P_T0_10_AH17
set_property PACKAGE_PIN AH17 [get_ports SHIFT_CLK10]
set_property IOSTANDARD LVCMOS25 [get_ports SHIFT_CLK10]
set_property DRIVE 8 [get_ports SHIFT_CLK10]
set_property SLEW SLOW [get_ports SHIFT_CLK10]
