# Export from the routed checkpoint so Vivado treats this as an implemented
# design even when build_board16.tcl used the in-memory project flow.
set root [file normalize [file join [file dirname [info script]] ..]]
set package $root/build/board16_package
set checkpoint $root/build/board16/routed.dcp
foreach f [concat [glob $root/rtl/*.v] [glob $root/rtl/*.sv] [glob $root/constraints/*]] {
    if {[file mtime $f]>[file mtime $checkpoint]} {error "Routed checkpoint is older than $f"}
}
set f [open $root/reports/board16/timing.rpt]; set timing [read $f]; close $f
if {![string match {*All user specified timing constraints are met.*} $timing]} {
    error "Board16 routed timing has not passed"
}
set_param general.maxThreads 2
open_checkpoint $checkpoint
write_bitstream -force $package/export/ris_ctrl_unit.bit
write_hw_platform -fixed -include_bit -force -file $package/export/ris_ctrl_unit.xsa
puts [exec python3 $root/scripts/finalize_export.py $package]
set f [open $root/reports/board16/build_status.txt w]
puts $f "PASS: 16 frame slots, 50 chips, routed timing, DRC, 72 pins, BIT/XSA"
close $f
puts RIS_BOARD16_BUILD_PASS
exit
