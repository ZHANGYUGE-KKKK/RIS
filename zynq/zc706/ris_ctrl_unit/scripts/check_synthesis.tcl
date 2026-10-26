set root [file normalize [file join [file dirname [info script]] ..]]
file mkdir $root/build/axi_synthesis $root/reports
open_project $root/vivado_axi/ris_ctrl_unit.xpr
foreach source_file [concat [glob $root/rtl/*.v] [glob $root/rtl/*.sv]] {
    if {![llength [get_files -quiet $source_file]]} {add_files -norecurse $source_file}
}
set bd [get_files */ris_system.bd]
open_bd_design $bd
update_module_reference [get_ips ris_system_controller_0]
validate_bd_design
save_bd_design
generate_target all $bd
update_compile_order -fileset sources_1
set_property PROCESSING_ORDER LATE [get_files */ris_lpc.xdc]
set_param general.maxThreads 4
set synthesis_directive RuntimeOptimized
if {[info exists ::env(RIS_SYNTH_DIRECTIVE)]} {set synthesis_directive $::env(RIS_SYNTH_DIRECTIVE)}
synth_design -top ris_ctrl_unit_top -part xc7z045ffg900-2 -directive $synthesis_directive
write_checkpoint -force $root/build/axi_synthesis/ris_ctrl_unit.dcp
report_utilization -file $root/reports/axi_synthesis_utilization.rpt
report_utilization -hierarchical -file $root/reports/axi_synthesis_hierarchy.rpt
report_io -file $root/reports/axi_synthesis_io.rpt
report_timing_summary -file $root/reports/axi_synthesis_timing.rpt
if {![llength [get_timing_paths -quiet -from [get_clocks clk_fpga_0] -to [get_clocks clk_fpga_0]]]} {
    error "Internal register-to-register timing paths are missing"
}
report_drc -file $root/reports/axi_synthesis_drc.rpt
set ris_ports [get_ports {ris_data[*] ris_shcp[*] ris_stcp[*] ris_mr_n ris_oe_n}]
if {[llength $ris_ports] != 72} {error "Expected 72 RIS pins"}
foreach port $ris_ports {
    if {[get_property PACKAGE_PIN $port] eq ""} {error "Missing pin for $port"}
    if {[get_property IOSTANDARD $port] ne "LVCMOS25"} {error "Wrong voltage for $port"}
}
if {[llength [get_cells -quiet -hier -filter {IS_BLACKBOX == 1}]]} {
    error "Unexpected black box in synthesized design"
}
set severe [get_drc_violations -quiet -filter {SEVERITY == Error || SEVERITY == {Critical Warning}}]
if {[llength $severe]} {error "Synthesis DRC failed: $severe"}
if {[get_msg_config -count -severity {CRITICAL WARNING}] != 0} {
    error "Critical warnings occurred; inspect the synthesis/constraint log"
}
close_project
puts RIS_AXI_SYNTHESIS_PASS
exit
