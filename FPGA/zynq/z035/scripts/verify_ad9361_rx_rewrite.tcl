# Standalone synthesis of the rewritten module, using existing vendor control
# blocks only. Does not open/update the active project or program hardware.
# Usage: vivado -mode batch -source scripts/verify_ad9361_rx_rewrite.tcl \
#             -tclargs /tmp/ad9361_rewrite_synth
set project_root [file normalize [file join [file dirname [info script]] ..]]
if {[llength $argv] > 1} {error "Expected at most one output directory"}
if {[llength $argv] == 1} {
    set output [file normalize [lindex $argv 0]]
} else {
    set output [file join $project_root reports ad9361_rewrite_synth_[clock format [clock seconds] -format %Y%m%d_%H%M%S]]
}
file mkdir $output
set vendor [file join $project_root PZ_UART.srcs sources_1 adi_hdl library]
create_project -in_memory ad9361_rewrite_validation -part xc7z035ffg900-2
set_property target_language Verilog [current_project]
set_property XPM_LIBRARIES {XPM_CDC XPM_FIFO XPM_MEMORY} [current_project]
read_verilog [glob $vendor/common/*.v]
read_verilog [glob $vendor/xilinx/common/*.v]
read_verilog [glob $vendor/axi_ad9361/*.v]
read_verilog $project_root/PZ_UART.srcs/sources_1/new/ad9361_rx_axis.v
synth_design -top ad9361_rx_axis -part xc7z035ffg900-2 -mode out_of_context
create_clock -name axis_clk -period 10.000 [get_ports m_axis_aclk]
create_clock -name delay_ref_clk -period 5.000 [get_ports ref_clk200]
create_clock -name rx_data_clk -period 16.276042 [get_ports rx_clk_p]
read_xdc $project_root/PZ_UART.srcs/constrs_1/new/ad9361_rx_cdc.xdc
foreach {module path} [list \
    ad_rst $vendor/xilinx/common/ad_rst_constr.xdc \
    up_xfer_cntrl $vendor/xilinx/common/up_xfer_cntrl_constr.xdc \
    up_xfer_status $vendor/xilinx/common/up_xfer_status_constr.xdc \
    up_clock_mon $vendor/xilinx/common/up_clock_mon_constr.xdc] {
    read_xdc -ref $module $path
}
report_utilization -file $output/utilization.rpt
report_cdc -details -file $output/cdc.rpt
report_drc -file $output/drc.rpt
report_timing_summary -file $output/timing_synthesis.rpt
write_checkpoint -force $output/ad9361_rx_axis_synth.dcp
puts "AD9361_REWRITE_SYNTH_COMPLETE=$output"
