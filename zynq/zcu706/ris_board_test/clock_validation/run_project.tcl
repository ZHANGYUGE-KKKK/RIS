set root [file dirname [file normalize [info script]]]
set project_dir [file dirname $root]
set reports [file join $root project_run]
file mkdir $reports
set rtl [file join $project_dir ris_board_test.srcs sources_1 new ris_clock_test.v]
set xdc [file join $project_dir ris_board_test.srcs constrs_1 new ris_clock_test_lpc.xdc]

if {[catch {
    open_project [file join $project_dir ris_board_test.xpr]
    if {[get_property PART [current_project]] ne "xc7z045ffg900-2"} {
        error "Unexpected project device"
    }
    if {[llength [get_files -quiet $rtl]] == 0} {
        add_files -norecurse -fileset sources_1 $rtl
    }
    if {[llength [get_files -quiet $xdc]] == 0} {
        add_files -norecurse -fileset constrs_1 $xdc
    }
    set_property top ris_clock_test [get_filesets sources_1]
    update_compile_order -fileset sources_1
    reset_run synth_1
    launch_runs synth_1 -jobs 4
    wait_on_run synth_1
    if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
        error "Synthesis failed: [get_property STATUS [get_runs synth_1]]"
    }
    launch_runs impl_1 -to_step write_bitstream -jobs 4
    wait_on_run impl_1
    if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
        error "Implementation failed: [get_property STATUS [get_runs impl_1]]"
    }
    open_run impl_1
    set xf [open $xdc r]
    set constraints [read $xf]
    close $xf
    set pf [open [file join $reports pin_verification.txt] w]
    set checked 0
    foreach line [split $constraints "\n"] {
        if {[regexp {^set_property PACKAGE_PIN (\S+) \[get_ports (\S+)\]} $line unused expected port]} {
            set actual [get_property PACKAGE_PIN [get_ports $port]]
            puts $pf "$port expected=$expected actual=$actual"
            if {$actual ne $expected} {
                close $pf
                error "Pin mismatch: $port expected $expected actual $actual"
            }
            incr checked
        }
    }
    puts $pf "PASS: $checked package pin constraints match routed design"
    close $pf
    if {$checked != 72} {error "Expected 72 constrained ports (20 CLK + 50 DATA + 2 SYSCLK), got $checked"}
    if {[llength [get_ports DATA_U*]] != 50} {
        error "Expected 50 DATA output ports"
    }
    if {[llength [get_cells -hier -filter {REF_NAME == ODDR}]] != 20} {
        error "Expected 20 separate ODDR instances"
    }
    report_io -file [file join $reports io.rpt]
    report_route_status -file [file join $reports route_status.rpt]
    report_drc -file [file join $reports drc.rpt]
    report_utilization -file [file join $reports utilization.rpt]
    report_timing_summary -file [file join $reports timing_summary.rpt]
    set f [open [file join $reports result.txt] w]
    puts $f "PASS: existing ris_board_test.xpr project"
    puts $f "synth_1: [get_property STATUS [get_runs synth_1]]"
    puts $f "impl_1: [get_property STATUS [get_runs impl_1]]"
    puts $f "72 pin constraints verified: 20 CLK + 50 DATA + 2 SYSCLK; 20 separate ODDR instances"
    close $f
    close_project
} reason]} {
    set f [open [file join $reports result.txt] w]
    puts $f "FAIL: $reason"
    close $f
    puts stderr $reason
    exit 1
}
exit 0
