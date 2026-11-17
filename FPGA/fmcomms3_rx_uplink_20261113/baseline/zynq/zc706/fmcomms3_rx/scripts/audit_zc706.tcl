# Inspect the routed design; no hardware connection is made.
set root [file normalize [file join [file dirname [info script]] ..]]
open_checkpoint $root/reports/implementation/routed.dcp
set fd [open $root/reports/implementation/board_audit.txt w]
if {[get_property PART [current_design]] ne "xc7z045ffg900-2"} {error "Wrong FPGA part"}
foreach {port pin standard} {
 rx_clk_p AF20 LVDS_25 rx_clk_n AG20 LVDS_25
 rx_frame_p AG21 LVDS_25 rx_frame_n AH21 LVDS_25
 SPI_9361_io0_io V28 LVCMOS25 SPI_9361_io1_io V29 LVCMOS25
 SPI_9361_sck_io T28 LVCMOS25 SPI_9361_ss_io R28 LVCMOS25
 GPIO_PS_tri_io[0] P30 LVCMOS25 cpu_reset A8 LVCMOS15 key_0 K15 LVCMOS15
} {
    set obj [get_ports $port]
    if {[get_property PACKAGE_PIN $obj] ne $pin || [get_property IOSTANDARD $obj] ne $standard} {
        error "Incorrect board binding: $port"
    }
    puts $fd "$port $pin $standard"
}
set rx_root u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst
set clock_buffer [get_cells $rx_root/u_clock_input]
if {![get_property DIFF_TERM $clock_buffer]} {error "HPC DATA_CLK differential termination disabled"}
foreach cell [get_cells -hier -filter {NAME =~ *ad9361_rx_axis_0* && REF_NAME == IBUFDS}] {
    if {![get_property DIFF_TERM $cell]} {error "HPC receiver termination disabled on $cell"}
    puts $fd "DIFF_TERM=TRUE $cell"
}
foreach {port count} {DDR3_0_dq 64 DDR3_0_dm 8 DDR3_0_dqs_p 8 DDR3_0_addr 14 DDR3_0_cs_n 2 DDR3_0_cke 2 DDR3_0_odt 2 DDR3_0_ck_p 2} {
    set matches [get_ports [format {%s[*]} $port]]
    if {[llength $matches] != $count} {error "Wrong SODIMM port width $port: [llength $matches]"}
    puts $fd "$port width=$count"
}
foreach {port pin} {{DDR3_0_cs_n[1]} H8 {DDR3_0_cke[1]} C7 {DDR3_0_odt[1]} C9 {DDR3_0_ck_p[1]} D9 {DDR3_0_ck_n[1]} D8} {
    if {[get_property PACKAGE_PIN [get_ports $port]] ne $pin} {error "Incorrect second-rank pin: $port"}
    puts $fd "DDR2G $port $pin"
}
set ref_clock [get_clocks -of_objects [get_pins $rx_root/u_delay_calibration/REFCLK]]
if {[llength $ref_clock]!=1 || abs([get_property PERIOD $ref_clock]-5.0)>0.001} {
    error "AD9361 IDELAY reference is not 200MHz: $ref_clock"
}
puts $fd "AD9361 IDELAY reference [get_property NAME $ref_clock] period=[get_property PERIOD $ref_clock]ns"
foreach port [get_ports] {
    if {[get_property PACKAGE_PIN $port] eq "" || [get_property IOSTANDARD $port] eq "DEFAULT"} {
        error "Unconstrained board port: $port"
    }
}
puts $fd "PASS all board port bindings, SODIMM widths and eight receive terminations"
close $fd
close_design
puts ZC706_BOARD_AUDIT_PASS
exit
