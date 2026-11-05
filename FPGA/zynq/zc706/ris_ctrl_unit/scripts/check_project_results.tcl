# Read-only inspection of genuine Project Mode runs; never launches a build.
set ris_root [file normalize [file join [file dirname [info script]] ..]]
set ris_reports $ris_root/reports/board16_project
file mkdir $ris_reports
set_param general.maxThreads 2
open_project -read_only $ris_root/vivado_board/ris_ctrl_unit.xpr
foreach run {synth_1 impl_1} {
    set r [get_runs $run]
    set status [get_property STATUS $r]
    if {[get_property PROGRESS $r] ne "100%" || ![string match {*Complete*} $status] ||
        [get_property NEEDS_REFRESH $r]} {error "$run is not complete/current: $status"}
    puts "PASS: $run $status"
}
open_run impl_1
report_utilization -hierarchical -file $ris_reports/utilization.rpt
report_drc -file $ris_reports/drc.rpt
report_route_status -file $ris_reports/route_status.rpt
report_io -file $ris_reports/io.rpt
check_timing -verbose -file $ris_reports/check_timing.rpt
report_timing_summary -max_paths 20 -file $ris_reports/timing.rpt
set f [open $ris_reports/timing.rpt]; set timing [read $f]; close $f
if {![string match {*All user specified timing constraints are met.*} $timing]} {
    error "Project Mode timing constraints were not met"
}
set severe [get_drc_violations -quiet -filter {SEVERITY == Error || SEVERITY == {Critical Warning}}]
if {[llength $severe]} {error "Project Mode DRC failed: $severe"}
set f [open $ris_reports/gui_status.txt w]
puts $f "PASS: synth_1/impl_1 complete and current; timing met; DRC clean; reports generated"
close $f
puts RIS_PROJECT_RESULTS_PASS
close_project
exit
