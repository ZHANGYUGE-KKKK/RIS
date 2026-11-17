set root [file normalize [file join [file dirname [info script]] ..]]
set f [open $root/reports/full2g_active.txt];set report [string trim [read $f]];close $f
open_project $root/vivado/PZ_UART.xpr
set_param general.maxThreads 8
set bd [get_files */design_1.bd]
open_bd_design $bd
source $root/scripts/configure_2g_ddr.tcl
source $root/scripts/configure_full_2g_address.tcl
validate_bd_design
save_bd_design
set_property synth_checkpoint_mode None $bd
generate_target all $bd
add_files -norecurse [make_wrapper -files $bd -top]
update_compile_order -fileset sources_1
write_bd_tcl -force $root/scripts/zc706_bd_export.tcl
report_ip_status -file $report/ip_status.rpt
set f [open $report/addresses.txt w]
foreach space [get_bd_addr_spaces] {
    puts $f "$space"
    foreach seg [get_bd_addr_segs -of_objects $space] {
        puts $f "$seg offset=[get_property OFFSET $seg] range=[get_property RANGE $seg]"
    }
}
close $f
close_project
puts FULL_DDR2G_PREPARED
exit
