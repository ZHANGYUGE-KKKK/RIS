# Run check_synthesis.tcl first; then run this script in Vivado batch mode.
# No timing exceptions are added here. A failing implementation is not exported.
set root [file normalize [file join [file dirname [info script]] ..]]
set out $root/build/board_v1
set report $root/reports/board_v1
file mkdir $out $report $root/export
set synth $root/build/axi_synthesis/ris_ctrl_unit.dcp
if {![file exists $synth]} {error "Run scripts/check_synthesis.tcl first"}
foreach f [concat [glob $root/rtl/*.v] [glob $root/rtl/*.sv] [glob $root/constraints/*]] {
    if {[file mtime $f] > [file mtime $synth]} {
        error "Synthesis checkpoint is older than $f; rerun check_synthesis.tcl"
    }
}
set_param general.maxThreads 4
open_checkpoint $synth
opt_design
place_design -directive Explore
phys_opt_design -directive Explore
write_checkpoint -force $out/placed.dcp
route_design -directive Explore
write_checkpoint -force $out/routed.dcp
report_timing_summary -max_paths 20 -file $report/timing.rpt
report_route_status -file $report/route_status.rpt
report_drc -file $report/drc.rpt
report_io -file $report/io.rpt
report_utilization -hierarchical -file $report/utilization.rpt
check_timing -verbose -file $report/check_timing.rpt
write_xdc -force $report/effective_constraints.xdc
set f [open $report/timing.rpt]; set timing [read $f]; close $f
if {![string match {*All user specified timing constraints are met.*} $timing]} {
    error "Timing failed; inspect reports/board_v1/timing.rpt (routed DCP retained)"
}
set severe [get_drc_violations -quiet -filter {SEVERITY == Error || SEVERITY == {Critical Warning}}]
if {[llength $severe]} {error "Implementation DRC failed: $severe"}
set ris_ports [get_ports {ris_data[*] ris_shcp[*] ris_stcp[*] ris_mr_n ris_oe_n}]
if {[llength $ris_ports] != 72} {error "Expected 72 RIS pins"}
foreach port $ris_ports {
    if {[get_property PACKAGE_PIN $port] eq "" || [get_property IOSTANDARD $port] ne "LVCMOS25"} {
        error "Invalid RIS pin constraint: $port"
    }
}
write_bitstream -force $root/export/ris_ctrl_unit.bit
write_hw_platform -fixed -include_bit -force -file $root/export/ris_ctrl_unit.xsa
exec python3 $root/scripts/finalize_export.py $root
set f [open $report/build_status.txt w]
puts $f "PASS: routed timing, DRC, 72 LVCMOS25 pins, BIT and XSA"
close $f
close_design
puts RIS_BOARD_BUILD_PASS
exit
