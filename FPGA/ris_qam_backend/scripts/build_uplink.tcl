# Independent vendor-ZC706 GEM1 SGMII implementation. Never accesses hardware.
set root [file normalize [file join [file dirname [info script]] ..]]
set out $root/build/pl_eth_sgmii_20261113
set report $root/reports/pl_eth_sgmii_20261113/hardware
set export $root/export_uplink
if {[info exists ::env(RIS_UPLINK_BUILD_DIR)]} {set out [file normalize $::env(RIS_UPLINK_BUILD_DIR)]}
if {[info exists ::env(RIS_UPLINK_REPORT_DIR)]} {set report [file normalize $::env(RIS_UPLINK_REPORT_DIR)]}
if {[info exists ::env(RIS_UPLINK_EXPORT_DIR)]} {set export [file normalize $::env(RIS_UPLINK_EXPORT_DIR)]}
file mkdir $out $report $export
set_param general.maxThreads 4
proc verify_sources {} {
    global report
    exec sha256sum --check --status $report/source_sha256.txt
}
proc worst_slack {delay} {
    set paths [get_timing_paths -quiet -delay_type $delay -max_paths 1]
    if {![llength $paths]} {error "No $delay timing paths found"}
    return [get_property SLACK [lindex $paths 0]]
}
verify_sources
open_project $out/project/ris_ctrl_unit.xpr
synth_design -top ris_ctrl_unit_top -part xc7z045ffg900-2 -directive RuntimeOptimized
write_checkpoint -force $out/synth.dcp
verify_sources
# Export the source-matched hardware handoff early for a parallel BSP build.
write_hw_platform -fixed -force -file $export/ris_ctrl_unit.xsa
set f [open $report/xsa_ready.txt w]
puts $f "SYNTHESIZED_NO_BIT_XSA $export/ris_ctrl_unit.xsa"
puts $f "SOURCE_MANIFEST $report/source_sha256.txt"
close $f
puts RIS_UPLINK_XSA_READY
report_utilization -file $report/synth_utilization.rpt
opt_design
place_design
phys_opt_design
write_checkpoint -force $out/placed.dcp
# Package pins must select the vendor board's GTX channel and REFCLK1 buffer.
set gts [get_cells -hierarchical -filter {REF_NAME == GTXE2_CHANNEL}]
if {[llength $gts] != 1} {error "Expected exactly one GTXE2_CHANNEL, got $gts"}
set gtloc [get_property LOC $gts]
if {$gtloc ne "GTXE2_CHANNEL_X0Y9"} {error "Wrong GTX placement: $gtloc"}
set refbufs [get_cells -hierarchical -filter {REF_NAME == IBUFDS_GTE2}]
if {[llength $refbufs] != 1} {error "Expected exactly one GT reference clock buffer"}
set refloc [get_property LOC $refbufs]
set f [open $report/physical_binding.txt w]
puts $f "GTX $gts $gtloc"
puts $f "REFCLK_BUFFER $refbufs $refloc"
foreach pair {{pl_eth_sgmii_txp Y2} {pl_eth_sgmii_txn Y1} {pl_eth_sgmii_rxp AB6} {pl_eth_sgmii_rxn AB5} {pl_eth_refclk_clk_p W8} {pl_eth_refclk_clk_n W7} {pl_eth_mdio_mdc L13} {pl_eth_mdio_mdio_io K13} {pl_eth_reset_n H14} {pl_eth_si5324_reset_n W23}} {
    lassign $pair port expected
    set pin [get_property PACKAGE_PIN [get_ports $port]]
    if {$pin ne $expected} {error "Wrong package pin for $port: $pin expected $expected"}
    puts $f "$port $pin [get_property IOSTANDARD [get_ports $port]]"
}
close $f
route_design
if {[worst_slack max] < 0 || [worst_slack min] < 0} {
    phys_opt_design -directive AggressiveExplore
    route_design -directive Explore
}
write_checkpoint -force $out/routed.dcp
report_timing_summary -max_paths 20 -file $report/timing.rpt
report_drc -file $report/drc.rpt
report_route_status -file $report/route_status.rpt
report_utilization -file $report/utilization.rpt
report_cdc -file $report/cdc.rpt
report_io -file $report/io.rpt
report_clocks -file $report/clocks.rpt
check_timing -verbose -file $report/check_timing.rpt
set f [open $report/timing.rpt];set timing [read $f];close $f
if {![string match {*All user specified timing constraints are met.*} $timing]} {error "Uplink timing failed; routed checkpoint retained"}
if {[llength [get_drc_violations -quiet -filter {SEVERITY == Error || SEVERITY == {Critical Warning}}]]} {error "Uplink DRC failed; routed checkpoint retained"}
verify_sources
# Export from the routed checkpoint without project run-state dependencies.
close_project
open_checkpoint $out/routed.dcp
write_bitstream -force $export/ris_ctrl_unit.bit
write_hw_platform -fixed -include_bit -force -file $export/ris_ctrl_unit.xsa
set f [open $report/build_pass.txt w]
puts $f "RIS_UPLINK_BUILD_PASS"
puts $f "WNS [worst_slack max]"
puts $f "WHS [worst_slack min]"
puts $f "GTX $gtloc"
puts $f "REFCLK_BUFFER $refloc"
close $f
close_project
puts RIS_UPLINK_BUILD_PASS
exit
