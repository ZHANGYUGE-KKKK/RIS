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

# BEGIN DATA PIN BINDINGS
# C22: FMC_LPC_LA18_CC_P; IO_L14P_T2_SRCC_12_AE27
set_property PACKAGE_PIN AE27 [get_ports DATA_U01]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U01]
set_property DRIVE 8 [get_ports DATA_U01]
set_property SLEW SLOW [get_ports DATA_U01]
# C23: FMC_LPC_LA18_CC_N; IO_L14N_T2_SRCC_12_AF27
set_property PACKAGE_PIN AF27 [get_ports DATA_U02]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U02]
set_property DRIVE 8 [get_ports DATA_U02]
set_property SLEW SLOW [get_ports DATA_U02]
# D20: FMC_LPC_LA17_CC_P; IO_L11P_T1_SRCC_12_AB27
set_property PACKAGE_PIN AB27 [get_ports DATA_U03]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U03]
set_property DRIVE 8 [get_ports DATA_U03]
set_property SLEW SLOW [get_ports DATA_U03]
# D21: FMC_LPC_LA17_CC_N; IO_L11N_T1_SRCC_12_AC27
set_property PACKAGE_PIN AC27 [get_ports DATA_U04]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U04]
set_property DRIVE 8 [get_ports DATA_U04]
set_property SLEW SLOW [get_ports DATA_U04]
# C26: FMC_LPC_LA27_P; IO_L21P_T3_DQS_12_AJ28
set_property PACKAGE_PIN AJ28 [get_ports DATA_U05]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U05]
set_property DRIVE 8 [get_ports DATA_U05]
set_property SLEW SLOW [get_ports DATA_U05]
# C27: FMC_LPC_LA27_N; IO_L21N_T3_DQS_12_AJ29
set_property PACKAGE_PIN AJ29 [get_ports DATA_U06]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U06]
set_property DRIVE 8 [get_ports DATA_U06]
set_property SLEW SLOW [get_ports DATA_U06]
# D23: FMC_LPC_LA23_P; IO_L24P_T3_12_AJ26
set_property PACKAGE_PIN AJ26 [get_ports DATA_U07]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U07]
set_property DRIVE 8 [get_ports DATA_U07]
set_property SLEW SLOW [get_ports DATA_U07]
# D24: FMC_LPC_LA23_N; IO_L24N_T3_12_AK26
set_property PACKAGE_PIN AK26 [get_ports DATA_U08]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U08]
set_property DRIVE 8 [get_ports DATA_U08]
set_property SLEW SLOW [get_ports DATA_U08]
# G33: FMC_LPC_LA31_P; IO_L9P_T1_DQS_12_AC29
set_property PACKAGE_PIN AC29 [get_ports DATA_U09]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U09]
set_property DRIVE 8 [get_ports DATA_U09]
set_property SLEW SLOW [get_ports DATA_U09]
# G34: FMC_LPC_LA31_N; IO_L9N_T1_DQS_12_AD29
set_property PACKAGE_PIN AD29 [get_ports DATA_U10]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U10]
set_property DRIVE 8 [get_ports DATA_U10]
set_property SLEW SLOW [get_ports DATA_U10]
# D26: FMC_LPC_LA26_P; IO_L20P_T3_12_AJ30
set_property PACKAGE_PIN AJ30 [get_ports DATA_U11]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U11]
set_property DRIVE 8 [get_ports DATA_U11]
set_property SLEW SLOW [get_ports DATA_U11]
# D27: FMC_LPC_LA26_N; IO_L20N_T3_12_AK30
set_property PACKAGE_PIN AK30 [get_ports DATA_U12]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U12]
set_property DRIVE 8 [get_ports DATA_U12]
set_property SLEW SLOW [get_ports DATA_U12]
# G2: FMC_LPC_CLK1_M2C_P; IO_L12P_T1_MRCC_12_AC28
set_property PACKAGE_PIN AC28 [get_ports DATA_U13]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U13]
set_property DRIVE 8 [get_ports DATA_U13]
set_property SLEW SLOW [get_ports DATA_U13]
# G3: FMC_LPC_CLK1_M2C_N; IO_L12N_T1_MRCC_12_AD28
set_property PACKAGE_PIN AD28 [get_ports DATA_U14]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U14]
set_property DRIVE 8 [get_ports DATA_U14]
set_property SLEW SLOW [get_ports DATA_U14]
# H4: FMC_LPC_CLK0_M2C_P; IO_L13P_T2_MRCC_10_AG17
set_property PACKAGE_PIN AG17 [get_ports DATA_U15]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U15]
set_property DRIVE 8 [get_ports DATA_U15]
set_property SLEW SLOW [get_ports DATA_U15]
# H5: FMC_LPC_CLK0_M2C_N; IO_L13N_T2_MRCC_10_AG16
set_property PACKAGE_PIN AG16 [get_ports DATA_U16]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U16]
set_property DRIVE 8 [get_ports DATA_U16]
set_property SLEW SLOW [get_ports DATA_U16]
# G6: FMC_LPC_LA00_CC_P; IO_L11P_T1_SRCC_10_AE13
set_property PACKAGE_PIN AE13 [get_ports DATA_U17]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U17]
set_property DRIVE 8 [get_ports DATA_U17]
set_property SLEW SLOW [get_ports DATA_U17]
# G7: FMC_LPC_LA00_CC_N; IO_L11N_T1_SRCC_10_AF13
set_property PACKAGE_PIN AF13 [get_ports DATA_U18]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U18]
set_property DRIVE 8 [get_ports DATA_U18]
set_property SLEW SLOW [get_ports DATA_U18]
# H7: FMC_LPC_LA02_P; IO_L7P_T1_10_AE12
set_property PACKAGE_PIN AE12 [get_ports DATA_U19]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U19]
set_property DRIVE 8 [get_ports DATA_U19]
set_property SLEW SLOW [get_ports DATA_U19]
# H8: FMC_LPC_LA02_N; IO_L7N_T1_10_AF12
set_property PACKAGE_PIN AF12 [get_ports DATA_U20]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U20]
set_property DRIVE 8 [get_ports DATA_U20]
set_property SLEW SLOW [get_ports DATA_U20]
# G9: FMC_LPC_LA03_P; IO_L10P_T1_10_AG12
set_property PACKAGE_PIN AG12 [get_ports DATA_U21]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U21]
set_property DRIVE 8 [get_ports DATA_U21]
set_property SLEW SLOW [get_ports DATA_U21]
# G10: FMC_LPC_LA03_N; IO_L10N_T1_10_AH12
set_property PACKAGE_PIN AH12 [get_ports DATA_U22]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U22]
set_property DRIVE 8 [get_ports DATA_U22]
set_property SLEW SLOW [get_ports DATA_U22]
# H10: FMC_LPC_LA04_P; IO_L5P_T0_10_AJ15
set_property PACKAGE_PIN AJ15 [get_ports DATA_U23]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U23]
set_property DRIVE 8 [get_ports DATA_U23]
set_property SLEW SLOW [get_ports DATA_U23]
# H11: FMC_LPC_LA04_N; IO_L5N_T0_10_AK15
set_property PACKAGE_PIN AK15 [get_ports DATA_U24]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U24]
set_property DRIVE 8 [get_ports DATA_U24]
set_property SLEW SLOW [get_ports DATA_U24]
# G12: FMC_LPC_LA08_P; IO_L9P_T1_DQS_10_AD14
set_property PACKAGE_PIN AD14 [get_ports DATA_U25]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U25]
set_property DRIVE 8 [get_ports DATA_U25]
set_property SLEW SLOW [get_ports DATA_U25]
# G13: FMC_LPC_LA08_N; IO_L9N_T1_DQS_10_AD13
set_property PACKAGE_PIN AD13 [get_ports DATA_U26]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U26]
set_property DRIVE 8 [get_ports DATA_U26]
set_property SLEW SLOW [get_ports DATA_U26]
# H13: FMC_LPC_LA07_P; IO_L20P_T3_10_AA15
set_property PACKAGE_PIN AA15 [get_ports DATA_U27]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U27]
set_property DRIVE 8 [get_ports DATA_U27]
set_property SLEW SLOW [get_ports DATA_U27]
# H14: FMC_LPC_LA07_N; IO_L20N_T3_10_AA14
set_property PACKAGE_PIN AA14 [get_ports DATA_U28]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U28]
set_property DRIVE 8 [get_ports DATA_U28]
set_property SLEW SLOW [get_ports DATA_U28]
# G15: FMC_LPC_LA12_P; IO_L18P_T2_10_AD16
set_property PACKAGE_PIN AD16 [get_ports DATA_U29]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U29]
set_property DRIVE 8 [get_ports DATA_U29]
set_property SLEW SLOW [get_ports DATA_U29]
# G16: FMC_LPC_LA12_N; IO_L18N_T2_10_AD15
set_property PACKAGE_PIN AD15 [get_ports DATA_U30]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U30]
set_property DRIVE 8 [get_ports DATA_U30]
set_property SLEW SLOW [get_ports DATA_U30]
# H16: FMC_LPC_LA11_P; IO_L4P_T0_10_AJ16
set_property PACKAGE_PIN AJ16 [get_ports DATA_U31]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U31]
set_property DRIVE 8 [get_ports DATA_U31]
set_property SLEW SLOW [get_ports DATA_U31]
# H17: FMC_LPC_LA11_N; IO_L4N_T0_10_AK16
set_property PACKAGE_PIN AK16 [get_ports DATA_U32]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U32]
set_property DRIVE 8 [get_ports DATA_U32]
set_property SLEW SLOW [get_ports DATA_U32]
# G18: FMC_LPC_LA16_P; IO_L17P_T2_10_AE18
set_property PACKAGE_PIN AE18 [get_ports DATA_U33]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U33]
set_property DRIVE 8 [get_ports DATA_U33]
set_property SLEW SLOW [get_ports DATA_U33]
# G19: FMC_LPC_LA16_N; IO_L17N_T2_10_AE17
set_property PACKAGE_PIN AE17 [get_ports DATA_U34]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U34]
set_property DRIVE 8 [get_ports DATA_U34]
set_property SLEW SLOW [get_ports DATA_U34]
# H19: FMC_LPC_LA15_P; IO_L22P_T3_10_AB15
set_property PACKAGE_PIN AB15 [get_ports DATA_U35]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U35]
set_property DRIVE 8 [get_ports DATA_U35]
set_property SLEW SLOW [get_ports DATA_U35]
# H20: FMC_LPC_LA15_N; IO_L22N_T3_10_AB14
set_property PACKAGE_PIN AB14 [get_ports DATA_U36]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U36]
set_property DRIVE 8 [get_ports DATA_U36]
set_property SLEW SLOW [get_ports DATA_U36]
# G21: FMC_LPC_LA20_P; IO_L17P_T2_12_AG26
set_property PACKAGE_PIN AG26 [get_ports DATA_U37]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U37]
set_property DRIVE 8 [get_ports DATA_U37]
set_property SLEW SLOW [get_ports DATA_U37]
# G22: FMC_LPC_LA20_N; IO_L17N_T2_12_AG27
set_property PACKAGE_PIN AG27 [get_ports DATA_U38]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U38]
set_property DRIVE 8 [get_ports DATA_U38]
set_property SLEW SLOW [get_ports DATA_U38]
# H22: FMC_LPC_LA19_P; IO_L23P_T3_12_AH26
set_property PACKAGE_PIN AH26 [get_ports DATA_U39]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U39]
set_property DRIVE 8 [get_ports DATA_U39]
set_property SLEW SLOW [get_ports DATA_U39]
# H23: FMC_LPC_LA19_N; IO_L23N_T3_12_AH27
set_property PACKAGE_PIN AH27 [get_ports DATA_U40]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U40]
set_property DRIVE 8 [get_ports DATA_U40]
set_property SLEW SLOW [get_ports DATA_U40]
# G24: FMC_LPC_LA22_P; IO_L22P_T3_12_AK27
set_property PACKAGE_PIN AK27 [get_ports DATA_U41]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U41]
set_property DRIVE 8 [get_ports DATA_U41]
set_property SLEW SLOW [get_ports DATA_U41]
# G25: FMC_LPC_LA22_N; IO_L22N_T3_12_AK28
set_property PACKAGE_PIN AK28 [get_ports DATA_U42]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U42]
set_property DRIVE 8 [get_ports DATA_U42]
set_property SLEW SLOW [get_ports DATA_U42]
# H25: FMC_LPC_LA21_P; IO_L19P_T3_12_AH28
set_property PACKAGE_PIN AH28 [get_ports DATA_U43]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U43]
set_property DRIVE 8 [get_ports DATA_U43]
set_property SLEW SLOW [get_ports DATA_U43]
# H26: FMC_LPC_LA21_N; IO_L19N_T3_VREF_12_AH29
set_property PACKAGE_PIN AH29 [get_ports DATA_U44]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U44]
set_property DRIVE 8 [get_ports DATA_U44]
set_property SLEW SLOW [get_ports DATA_U44]
# G27: FMC_LPC_LA25_P; IO_L15P_T2_DQS_12_AF29
set_property PACKAGE_PIN AF29 [get_ports DATA_U45]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U45]
set_property DRIVE 8 [get_ports DATA_U45]
set_property SLEW SLOW [get_ports DATA_U45]
# G28: FMC_LPC_LA25_N; IO_L15N_T2_DQS_12_AG29
set_property PACKAGE_PIN AG29 [get_ports DATA_U46]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U46]
set_property DRIVE 8 [get_ports DATA_U46]
set_property SLEW SLOW [get_ports DATA_U46]
# H28: FMC_LPC_LA24_P; IO_L16P_T2_12_AF30
set_property PACKAGE_PIN AF30 [get_ports DATA_U47]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U47]
set_property DRIVE 8 [get_ports DATA_U47]
set_property SLEW SLOW [get_ports DATA_U47]
# H29: FMC_LPC_LA24_N; IO_L16N_T2_12_AG30
set_property PACKAGE_PIN AG30 [get_ports DATA_U48]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U48]
set_property DRIVE 8 [get_ports DATA_U48]
set_property SLEW SLOW [get_ports DATA_U48]
# G30: FMC_LPC_LA29_P; IO_L18P_T2_12_AE25
set_property PACKAGE_PIN AE25 [get_ports DATA_U49]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U49]
set_property DRIVE 8 [get_ports DATA_U49]
set_property SLEW SLOW [get_ports DATA_U49]
# G31: FMC_LPC_LA29_N; IO_L18N_T2_12_AF25
set_property PACKAGE_PIN AF25 [get_ports DATA_U50]
set_property IOSTANDARD LVCMOS25 [get_ports DATA_U50]
set_property DRIVE 8 [get_ports DATA_U50]
set_property SLEW SLOW [get_ports DATA_U50]
# END DATA PIN BINDINGS
