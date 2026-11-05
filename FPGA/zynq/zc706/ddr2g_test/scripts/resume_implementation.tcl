set root [file normalize [file join [file dirname [info script]] ..]]
open_checkpoint $root/reports/synth.dcp
set_param general.maxThreads 8
set ctrls [get_cells -hier -filter {REF_NAME == IDELAYCTRL}]
foreach c $ctrls {
    puts "IDELAY_CTRL $c group=[get_property IODELAY_GROUP $c]"
}
set unused [get_cells -hier -filter {REF_NAME == IDELAYCTRL && IODELAY_GROUP == DDR_TEST_MIG_0_IODELAY_MIG0}]
if {[llength $unused] != 1} {error "Expected exactly one unused 200MHz delay controller"}
# Keep the readiness generator; its 200MHz group has no delay elements in this
# MIG speed mode. Leave it ungrouped so the placer can allocate a spare bank.
reset_property IODELAY_GROUP $unused
opt_design
place_design -directive Explore
write_checkpoint -force $root/reports/placed.dcp
phys_opt_design -directive Explore
route_design -directive Explore
write_checkpoint -force $root/reports/routed.dcp
report_timing_summary -max_paths 10 -file $root/reports/timing.rpt
report_drc -file $root/reports/drc.rpt
report_io -file $root/reports/io.rpt
report_cdc -details -file $root/reports/cdc.rpt
report_route_status -file $root/reports/route_status.rpt
foreach typ {max min} {
    if {[llength [get_timing_paths -quiet -delay_type $typ -slack_lesser_than 0 -max_paths 1]]} {error "Timing failed: $typ"}
}
if {[llength [get_drc_violations -quiet -filter {SEVERITY == Error}]]} {error "DRC errors"}
write_bitstream -force $root/export/ddr2g_test.bit
write_hw_platform -fixed -include_bit -force -file $root/export/ddr2g_test.xsa
puts DDR2G_HARDWARE_BUILD_PASS
close_design
exit
