set spi_verify_dir [file normalize [file join [file dirname [info script]] ..]]
open_project [file join $spi_verify_dir PZ_UART.xpr]
set_param general.maxThreads 4
# Exercise wrapper regeneration before checking the hand-written board top.
if {[get_property TOP [get_filesets sources_1]] eq "pz7035_top"} {
    set spi_bd_file [get_files */design_1.bd]
    open_bd_design $spi_bd_file
    make_wrapper -files $spi_bd_file -top -force
}
update_compile_order -fileset sources_1
synth_design -rtl -name spi_pin_check -top [get_property TOP [get_filesets sources_1]] -part [get_property PART [current_project]]
read_xdc [file join $spi_verify_dir PZ_UART.srcs constrs_1 new key_ctrl_55_jm1.xdc]
foreach {port_name expected_ball} {
    SPI_9361_io0_io U25
    SPI_9361_io1_io N26
    SPI_9361_sck_io V26
    SPI_9361_ss_io T22
} {
    set port_obj [get_ports $port_name]
    set ball [get_property PACKAGE_PIN $port_obj]
    set standard [get_property IOSTANDARD $port_obj]
    if {$ball ne $expected_ball || $standard ne "LVCMOS18"} {
        error "Incorrect SPI binding: $port_name $ball $standard"
    }
    set owners [get_ports -filter "PACKAGE_PIN == $ball"]
    if {[llength $owners] != 1} {error "Duplicate assignment on $ball: $owners"}
    puts "SPI_PIN_CHECK: $port_name -> $ball / $standard"
}
if {[llength [get_ports -quiet {SPI_9361_ss1_o SPI_9361_ss2_o}]]} {
    error "Unused SPI chip selects are still exposed."
}
if {![get_property PULLUP [get_ports SPI_9361_ss_io]]} {
    error "AD9361 chip select pull-up is missing."
}
report_io -file [file join $spi_verify_dir reports rfmc_spi_io.rpt]
puts "RFMC_SPI_PIN_CHECK_PASS"
close_project
