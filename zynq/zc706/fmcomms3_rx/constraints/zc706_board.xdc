# Fixed 200 MHz board oscillator, H9/G9, bank 34 VCCO=1.5 V.
# External 100 Ohm clock termination is on the ZC706 PCB.
set_property -dict {PACKAGE_PIN H9 IOSTANDARD DIFF_SSTL15} [get_ports {sys_clk_clk_p[0]}]
set_property -dict {PACKAGE_PIN G9 IOSTANDARD DIFF_SSTL15} [get_ports {sys_clk_clk_n[0]}]
create_clock -name board_clk200 -period 5.000 [get_ports {sys_clk_clk_p[0]}]
# SW13 PL_CPU_RESET is active HIGH; the board wrapper inverts it for old rstn.
set_property -dict {PACKAGE_PIN A8 IOSTANDARD LVCMOS15} [get_ports cpu_reset]
set_false_path -from [get_ports cpu_reset]
# SW9 centre button is active HIGH; the wrapper preserves old KEY1 polarity.
set_property -dict {PACKAGE_PIN K15 IOSTANDARD LVCMOS15} [get_ports key_0]
set_false_path -from [get_ports key_0]
# Static register-controlled ENSM/MGC outputs have no external sampling clock.
set_false_path -to [get_ports {rf_enable rf_txnrx rf_en_agc rf_sync_in}]
# PS SPI uses EMIO at low speed and is polled by software; apply a generous
# external round-trip bound rather than borrowing the RX source clock.
set_max_delay 20.000 -datapath_only -from [get_ports SPI_9361_io1_io]
# DDR3 RESET# is an asynchronous JEDEC initialization control, not DQ data.
set_false_path -to [get_ports DDR3_0_reset_n]
