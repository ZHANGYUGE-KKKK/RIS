# Standalone synthesis; does not open or rebuild the user's active project.
set stage1_root [file normalize [file join [file dirname [info script]] ..]]
set stage1_out $stage1_root/reports/rx_incremental_stage1_20261016
file mkdir $stage1_out
create_project -in_memory -part xc7z035ffg900-2
set stage1_vendor $stage1_root/PZ_UART.srcs/sources_1/adi_hdl
read_verilog $stage1_vendor/library/xilinx/common/ad_data_clk.v
read_verilog $stage1_vendor/library/xilinx/common/ad_data_in.v
read_verilog $stage1_root/PZ_UART.srcs/sources_1/new/ad9361_rx_lvds_if.v
synth_design -top ad9361_rx_lvds_if -part xc7z035ffg900-2 -mode out_of_context
create_clock -name data_clk -period 4.069 [get_ports rx_clk_in_p]
create_clock -name ref200 -period 5.000 [get_ports delay_clk]
create_clock -name up100 -period 10.000 [get_ports up_clk]
report_utilization -file $stage1_out/frontend_utilization.rpt
report_timing_summary -file $stage1_out/frontend_synth_timing.rpt
set stage1_fd [open $stage1_out/frontend_structure.txt w]
foreach {ref count} {IDDR 7 IDELAYE2 7 IDELAYCTRL 1 BUFG 1} {
    set found [llength [get_cells -hier -filter "REF_NAME == $ref"]]
    puts $stage1_fd "$ref $found expected=$count"
    if {$found != $count} {close $stage1_fd;error "Unexpected $ref count $found"}
}
set stage1_latches [get_cells -quiet -hier -filter {REF_NAME =~ LD*}]
set stage1_blackboxes [get_cells -quiet -hier -filter {IS_BLACKBOX == 1}]
puts $stage1_fd "LATCHES [llength $stage1_latches] BLACKBOXES [llength $stage1_blackboxes]"
close $stage1_fd
if {[llength $stage1_latches] || [llength $stage1_blackboxes]} {
    error "Unexpected latch or unresolved module"
}
write_checkpoint -force $stage1_out/frontend_synth.dcp
puts AD9361_RX_STAGE1_SYNTH_PASS
close_project

# Elaborate/synthesize the unchanged public AXI/AXIS boundary as well.
create_project -in_memory -part xc7z035ffg900-2
set_property XPM_LIBRARIES {XPM_CDC XPM_FIFO XPM_MEMORY} [current_project]
foreach file [concat [glob $stage1_vendor/library/common/*.v] \
                     [glob $stage1_vendor/library/xilinx/common/*.v] \
                     [glob $stage1_vendor/library/axi_ad9361/*.v] \
                     [glob $stage1_vendor/library/axi_ad9361/xilinx/*.v]] {
    read_verilog $file
}
read_verilog $stage1_root/PZ_UART.srcs/sources_1/new/ad9361_rx_lvds_if.v
read_verilog $stage1_root/PZ_UART.srcs/sources_1/new/ad9361_rx_axis.v
synth_design -top ad9361_rx_axis -part xc7z035ffg900-2 -mode out_of_context
report_utilization -file $stage1_out/axis_utilization.rpt
set stage1_blackboxes [get_cells -quiet -hier -filter {IS_BLACKBOX == 1}]
if {[llength $stage1_blackboxes]} {error "Unresolved integrated receiver module"}
write_checkpoint -force $stage1_out/axis_synth.dcp
puts AD9361_RX_STAGE1_AXIS_SYNTH_PASS
close_project
exit
