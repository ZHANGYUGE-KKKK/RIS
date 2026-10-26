# ZC706 fixed oscillator, 200 MHz; external termination is fitted on the board.
set_property -dict {PACKAGE_PIN H9 IOSTANDARD DIFF_SSTL15} [get_ports sys_clk_clk_p]
set_property -dict {PACKAGE_PIN G9 IOSTANDARD DIFF_SSTL15} [get_ports sys_clk_clk_n]
create_clock -name board_clk200 -period 5.000 [get_ports sys_clk_clk_p]
set_property -dict {PACKAGE_PIN A8 IOSTANDARD LVCMOS15} [get_ports cpu_reset]
set_false_path -from [get_ports cpu_reset]
set_false_path -to [get_ports DDR3_reset_n]
# PS FCLK and the board oscillator are independent. Only the receiving first
# synchronizer stages are exempted. Final diagnostic fields are held stable
# until the next command; DONE crosses an extra stage before software uses them.
set_false_path -to [get_pins -hier -filter {NAME =~ */command_meta_reg*/D || NAME =~ */start_meta_reg/D || NAME =~ */diag/inst/meta_reg*/D || NAME =~ */done_meta_reg/D}]
