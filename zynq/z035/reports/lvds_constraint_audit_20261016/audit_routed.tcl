# Read-only inspection of the last full routed design, not a project rebuild.
set audit_out [file dirname [file normalize [info script]]]
set audit_root [file normalize [file join $audit_out ../..]]
open_checkpoint $audit_root/PZ_UART.runs/impl_1/pz7035_top_routed.dcp
proc property_or_empty {object property} {
    if {[lsearch -exact [list_property $object] $property]<0} {return "<not exposed>"}
    return [get_property $property $object]
}
set audit_fd [open $audit_out/routed_findings.txt w]
puts $audit_fd "DESIGN [current_design] PART [get_property PART [current_design]]"
foreach port [lsort [get_ports -quiet -regexp {rx_(clk|frame|data)_[pn](\[[0-5]\])?}]] {
    set pad [get_package_pins -of_objects $port]
    puts $audit_fd "PORT $port PIN=[get_property PACKAGE_PIN $port] IOSTANDARD=[get_property IOSTANDARD $port] DIFF_TERM=[property_or_empty $port DIFF_TERM] PAD=$pad PIN_FUNC=[property_or_empty $pad PIN_FUNC] BANK=[property_or_empty $pad BANK]"
}
foreach cell [lsort [get_cells -hier -filter {NAME =~ *ad9361_rx_axis_0* && (REF_NAME =~ IBUF* || REF_NAME == BUFG || REF_NAME == IDDR || REF_NAME == IDELAYE2 || REF_NAME == IDELAYCTRL)}]] {
    puts $audit_fd "CELL $cell TYPE=[get_property REF_NAME $cell] LOC=[get_property LOC $cell] IOSTANDARD=[property_or_empty $cell IOSTANDARD] DIFF_TERM=[property_or_empty $cell DIFF_TERM] IBUF_LOW_PWR=[property_or_empty $cell IBUF_LOW_PWR] GROUP=[property_or_empty $cell IODELAY_GROUP]"
}
foreach clock [get_clocks -of_objects [get_ports rx_clk_p]] {
    puts $audit_fd "CLOCK $clock PERIOD=[get_property PERIOD $clock] WAVEFORM=[get_property WAVEFORM $clock]"
}
foreach net [get_nets -hier -filter {NAME =~ *ad9361_rx_axis_0/inst/rx_clk || NAME =~ *ad9361_rx_axis_0/inst/i_dev_if/i_clk/clk_ibuf_s}] {
    puts $audit_fd "CLOCK_NET $net DEDICATED_ROUTE=[property_or_empty $net CLOCK_DEDICATED_ROUTE]"
    foreach pin [get_pins -of_objects $net -filter {DIRECTION == OUT}] {puts $audit_fd "  DRIVER $pin"}
}
close $audit_fd
report_io -file $audit_out/io.rpt
report_clock_networks -file $audit_out/clock_networks.rpt
check_timing -verbose -file $audit_out/check_timing.rpt
report_timing -from [get_ports {rx_frame_p rx_data_p[*]}] -max_paths 8 -path_type full_clock_expanded -file $audit_out/input_paths.rpt
report_drc -file $audit_out/drc.rpt
write_xdc -force $audit_out/effective_constraints.xdc
puts LVDS_ROUTED_CONSTRAINT_AUDIT_COMPLETE
close_design
exit
