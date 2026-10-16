set_property PACKAGE_PIN H9 [get_ports sysclk_p]
set_property PACKAGE_PIN G9 [get_ports sysclk_n]
set_property IOSTANDARD LVDS [get_ports {sysclk_p sysclk_n}]
create_clock -name sysclk -period 5.000 [get_ports sysclk_p]
# C3: FMC_HPC_DP0_C2M_N; MGTXTXN0_109_AK9
set_property PACKAGE_PIN AK9 [get_ports LATCH_CLK1]
set_property IOSTANDARD LVCMOS25 [get_ports LATCH_CLK1]
set_property DRIVE 8 [get_ports LATCH_CLK1]
set_property SLEW SLOW [get_ports LATCH_CLK1]
# C2: FMC_HPC_DP0_C2M_P; MGTXTXP0_109_AK10
set_property PACKAGE_PIN AK10 [get_ports SHIFT_CLK1]
set_property IOSTANDARD LVCMOS25 [get_ports SHIFT_CLK1]
set_property DRIVE 8 [get_ports SHIFT_CLK1]
set_property SLEW SLOW [get_ports SHIFT_CLK1]
# H35: FMC_HPC_LA30_N; IO_L18N_T2_13_P24
set_property PACKAGE_PIN P24 [get_ports LATCH_CLK2]
set_property IOSTANDARD LVCMOS25 [get_ports LATCH_CLK2]
set_property DRIVE 8 [get_ports LATCH_CLK2]
set_property SLEW SLOW [get_ports LATCH_CLK2]
# H34: FMC_HPC_LA30_P; IO_L18P_T2_13_P23
set_property PACKAGE_PIN P23 [get_ports SHIFT_CLK2]
set_property IOSTANDARD LVCMOS25 [get_ports SHIFT_CLK2]
set_property DRIVE 8 [get_ports SHIFT_CLK2]
set_property SLEW SLOW [get_ports SHIFT_CLK2]
# C7: FMC_HPC_DP0_M2C_N; MGTXRXN0_109_AH9
set_property PACKAGE_PIN AH9 [get_ports LATCH_CLK3]
set_property IOSTANDARD LVCMOS25 [get_ports LATCH_CLK3]
set_property DRIVE 8 [get_ports LATCH_CLK3]
set_property SLEW SLOW [get_ports LATCH_CLK3]
# C6: FMC_HPC_DP0_M2C_P; MGTXRXP0_109_AH10
set_property PACKAGE_PIN AH10 [get_ports SHIFT_CLK3]
set_property IOSTANDARD LVCMOS25 [get_ports SHIFT_CLK3]
set_property DRIVE 8 [get_ports SHIFT_CLK3]
set_property SLEW SLOW [get_ports SHIFT_CLK3]
# D9: FMC_HPC_LA01_CC_N; IO_L13N_T2_MRCC_11_AH21
set_property PACKAGE_PIN AH21 [get_ports LATCH_CLK4]
set_property IOSTANDARD LVCMOS25 [get_ports LATCH_CLK4]
set_property DRIVE 8 [get_ports LATCH_CLK4]
set_property SLEW SLOW [get_ports LATCH_CLK4]
# D8: FMC_HPC_LA01_CC_P; IO_L13P_T2_MRCC_11_AG21
set_property PACKAGE_PIN AG21 [get_ports SHIFT_CLK4]
set_property IOSTANDARD LVCMOS25 [get_ports SHIFT_CLK4]
set_property DRIVE 8 [get_ports SHIFT_CLK4]
set_property SLEW SLOW [get_ports SHIFT_CLK4]
# C11: FMC_HPC_LA06_N; IO_L6N_T0_VREF_11_AH22
set_property PACKAGE_PIN AH22 [get_ports LATCH_CLK5]
set_property IOSTANDARD LVCMOS25 [get_ports LATCH_CLK5]
set_property DRIVE 8 [get_ports LATCH_CLK5]
set_property SLEW SLOW [get_ports LATCH_CLK5]
# C10: FMC_HPC_LA06_P; IO_L6P_T0_11_AG22
set_property PACKAGE_PIN AG22 [get_ports SHIFT_CLK5]
set_property IOSTANDARD LVCMOS25 [get_ports SHIFT_CLK5]
set_property DRIVE 8 [get_ports SHIFT_CLK5]
set_property SLEW SLOW [get_ports SHIFT_CLK5]
# D12: FMC_HPC_LA05_N; IO_L5N_T0_11_AH24
set_property PACKAGE_PIN AH24 [get_ports LATCH_CLK6]
set_property IOSTANDARD LVCMOS25 [get_ports LATCH_CLK6]
set_property DRIVE 8 [get_ports LATCH_CLK6]
set_property SLEW SLOW [get_ports LATCH_CLK6]
# D11: FMC_HPC_LA05_P; IO_L5P_T0_11_AH23
set_property PACKAGE_PIN AH23 [get_ports SHIFT_CLK6]
set_property IOSTANDARD LVCMOS25 [get_ports SHIFT_CLK6]
set_property DRIVE 8 [get_ports SHIFT_CLK6]
set_property SLEW SLOW [get_ports SHIFT_CLK6]
# C15: FMC_HPC_LA10_N; IO_L8N_T1_11_AG25
set_property PACKAGE_PIN AG25 [get_ports LATCH_CLK7]
set_property IOSTANDARD LVCMOS25 [get_ports LATCH_CLK7]
set_property DRIVE 8 [get_ports LATCH_CLK7]
set_property SLEW SLOW [get_ports LATCH_CLK7]
# C14: FMC_HPC_LA10_P; IO_L8P_T1_11_AG24
set_property PACKAGE_PIN AG24 [get_ports SHIFT_CLK7]
set_property IOSTANDARD LVCMOS25 [get_ports SHIFT_CLK7]
set_property DRIVE 8 [get_ports SHIFT_CLK7]
set_property SLEW SLOW [get_ports SHIFT_CLK7]
# D15: FMC_HPC_LA09_N; IO_L10N_T1_11_AE21
set_property PACKAGE_PIN AE21 [get_ports LATCH_CLK8]
set_property IOSTANDARD LVCMOS25 [get_ports LATCH_CLK8]
set_property DRIVE 8 [get_ports LATCH_CLK8]
set_property SLEW SLOW [get_ports LATCH_CLK8]
# D14: FMC_HPC_LA09_P; IO_L10P_T1_11_AD21
set_property PACKAGE_PIN AD21 [get_ports SHIFT_CLK8]
set_property IOSTANDARD LVCMOS25 [get_ports SHIFT_CLK8]
set_property DRIVE 8 [get_ports SHIFT_CLK8]
set_property SLEW SLOW [get_ports SHIFT_CLK8]
# C19: FMC_HPC_LA14_N; IO_L7N_T1_11_AD24
set_property PACKAGE_PIN AD24 [get_ports LATCH_CLK9]
set_property IOSTANDARD LVCMOS25 [get_ports LATCH_CLK9]
set_property DRIVE 8 [get_ports LATCH_CLK9]
set_property SLEW SLOW [get_ports LATCH_CLK9]
# C18: FMC_HPC_LA14_P; IO_L7P_T1_11_AC24
set_property PACKAGE_PIN AC24 [get_ports SHIFT_CLK9]
set_property IOSTANDARD LVCMOS25 [get_ports SHIFT_CLK9]
set_property DRIVE 8 [get_ports SHIFT_CLK9]
set_property SLEW SLOW [get_ports SHIFT_CLK9]
# D18: FMC_HPC_LA13_N; IO_L23N_T3_11_AA23
set_property PACKAGE_PIN AA23 [get_ports LATCH_CLK10]
set_property IOSTANDARD LVCMOS25 [get_ports LATCH_CLK10]
set_property DRIVE 8 [get_ports LATCH_CLK10]
set_property SLEW SLOW [get_ports LATCH_CLK10]
# D17: FMC_HPC_LA13_P; IO_L23P_T3_11_AA22
set_property PACKAGE_PIN AA22 [get_ports SHIFT_CLK10]
set_property IOSTANDARD LVCMOS25 [get_ports SHIFT_CLK10]
set_property DRIVE 8 [get_ports SHIFT_CLK10]
set_property SLEW SLOW [get_ports SHIFT_CLK10]
