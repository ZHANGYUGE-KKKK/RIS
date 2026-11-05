set root [file normalize [file join [file dirname [info script]] ..]]
open_checkpoint $root/reports/routed.dcp
source $root/scripts/mig_delay_groups.tcl
set output [open $root/reports/physical_checks.txt w]
foreach {port pin} {
    {DDR3_cs_n[1]} H8 {DDR3_cke[1]} C7 {DDR3_odt[1]} C9
    {DDR3_ck_p[1]} D9 {DDR3_ck_n[1]} D8
    {sys_clk_clk_p[0]} H9 {sys_clk_clk_n[0]} G9 cpu_reset A8
} {
    set obj [get_ports $port]
    set actual [get_property PACKAGE_PIN $obj]
    if {$actual ne $pin} {error "Wrong pin: $port=$actual (expected $pin)"}
    puts $output "PIN PASS $port $actual [get_property IOSTANDARD $obj]"
}
foreach c [get_cells -hier -filter {REF_NAME == IDELAYCTRL}] {
    puts $output "IDELAYCTRL $c LOC=[get_property LOC $c] GROUP=[get_property IODELAY_GROUP $c]"
}
foreach d [get_cells -hier -filter {REF_NAME =~ IDELAYE2*}] {
    if {[get_property IODELAY_GROUP $d] ne "DDR_TEST_MIG_0_IODELAY_MIG1"} {error "Data calibration group changed"}
}
puts $output "64 MIG data delays retain their 400MHz group; unused 200MHz readiness controller remains connected."
close $output
report_clocks -file $root/reports/clocks.rpt
close_design
open_project $root/vivado/ddr2g_test.xpr
if {![llength [get_files -quiet */mig_delay_groups.tcl]]} {
    add_files -fileset utils_1 -norecurse $root/scripts/mig_delay_groups.tcl
}
set_property STEPS.SYNTH_DESIGN.TCL.POST $root/scripts/mig_delay_groups.tcl [get_runs synth_1]
close_project
puts DDR2G_PHYSICAL_CHECKS_PASS
exit
