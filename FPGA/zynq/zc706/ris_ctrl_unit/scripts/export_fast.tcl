set root [file normalize [file join [file dirname [info script]] ..]]
set checkpoint $root/build/fast_toggle/routed.dcp
foreach f [concat [glob $root/rtl/*.v] [glob $root/rtl/*.sv] [glob $root/constraints/*]] {
    if {[file mtime $f]>[file mtime $checkpoint]} {error "Routed fast checkpoint is older than $f"}
}
set f [open $root/reports/fast_toggle/timing.rpt];set timing [read $f];close $f
if {![string match {*All user specified timing constraints are met.*} $timing]} {error "Fast-toggle routed timing has not passed"}
open_checkpoint $checkpoint
write_bitstream -force $root/export_network_fast/ris_ctrl_unit.bit
write_hw_platform -fixed -include_bit -force -file $root/export_network_fast/ris_ctrl_unit.xsa
close_project
puts RIS_FAST_EXPORT_PASS
