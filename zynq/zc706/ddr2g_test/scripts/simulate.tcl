set root [file normalize [file join [file dirname [info script]] ..]]
create_project sim_test $root/reports/sim_project -part xc7z045ffg900-2 -force
add_files $root/rtl/ddr_bist.sv
add_files -fileset sim_1 $root/tests/tb_ddr_bist.sv
set_property top tb_ddr_bist [get_filesets sim_1]
set_property xsim.simulate.runtime all [get_filesets sim_1]
launch_simulation
close_sim
set transcript $root/reports/sim_project/sim_test.sim/sim_1/behav/xsim/simulate.log
set f [open $transcript r]
set result [read $f]
close $f
if {![string match *DDR2G_BIST_SIM_PASS* $result] || [regexp {Fatal:|FATAL:|Error:} $result]} {
    error "BIST simulation did not pass; see $transcript"
}
close_project
exit
