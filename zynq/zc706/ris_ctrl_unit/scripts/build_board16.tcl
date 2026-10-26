# First-board configuration: same AXI4/50-chip RTL, 16 frame slots (1 KiB).
set root [file normalize [file join [file dirname [info script]] ..]]
set out $root/build/board16
set package $root/build/board16_package
set report $root/reports/board16
file mkdir $out $report $package/export
set_param general.maxThreads 2
open_project $root/vivado_board/ris_ctrl_unit.xpr
synth_design -top ris_ctrl_unit_top -part xc7z045ffg900-2 -directive RuntimeOptimized
write_checkpoint -force $out/synth.dcp
opt_design
place_design -directive Default
phys_opt_design -directive Default
write_checkpoint -force $out/placed.dcp
route_design -directive Default
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
    error "Board16 timing failed; routed DCP retained"
}
set severe [get_drc_violations -quiet -filter {SEVERITY == Error || SEVERITY == {Critical Warning}}]
if {[llength $severe]} {error "Board16 DRC failed: $severe"}
set ports [get_ports {ris_data[*] ris_shcp[*] ris_stcp[*] ris_mr_n ris_oe_n}]
if {[llength $ports]!=72} {error "Expected 72 RIS pins"}
foreach port $ports {
    if {[get_property PACKAGE_PIN $port] eq "" || [get_property IOSTANDARD $port] ne "LVCMOS25"} {
        error "Invalid RIS pin: $port"
    }
}
close_project
source $root/scripts/export_board16.tcl
