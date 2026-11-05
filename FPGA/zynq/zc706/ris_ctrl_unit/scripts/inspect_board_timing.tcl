set root [file normalize [file join [file dirname [info script]] ..]]
set checkpoint $root/build/board_v1/routed.dcp
if {[llength $argv]} {set checkpoint [file normalize [lindex $argv 0]]}
open_checkpoint $checkpoint
report_timing -max_paths 15 -path_type full_clock_expanded -file $root/reports/board_v1/critical_paths.rpt
close_design
exit
