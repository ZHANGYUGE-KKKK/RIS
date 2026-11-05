# In the Vivado Tcl Console: source scripts/gui_board_results.tcl
# Uses genuine Project Mode runs so results persist in Design Runs/Reports.
# Leaves the accepted export packages and running board untouched.
namespace eval ::ris_board_gui {
    variable ris_root [file normalize [file join [file dirname [info script]] ..]]
    variable ris_reports $ris_root/reports/board16_project
    variable ris_phase synth
    variable ris_timer
    if {![info exists ris_timer]} {set ris_timer {}}

    proc status {message} {
        variable ris_reports
        set f [open $ris_reports/gui_status.txt w]
        puts $f $message
        close $f
        puts "RIS_GUI: $message"
    }
    proc complete {run} {
        expr {[get_property PROGRESS [get_runs $run]] eq "100%" &&
              [string match {*Complete*} [get_property STATUS [get_runs $run]]]}
    }
    proc finish {} {
        variable ris_reports
        if {[get_property NEEDS_REFRESH [get_runs synth_1]] ||
            [get_property NEEDS_REFRESH [get_runs impl_1]]} {
            error "Run sources changed during compilation; results need refresh"
        }
        open_run impl_1
        set tag [clock format [clock seconds] -format %Y%m%d_%H%M%S]
        # Vivado 2020.2 does not allow -name with -hierarchical.
        report_utilization -hierarchical -file $ris_reports/utilization.rpt
        report_utilization -name RIS_board16_utilization_$tag
        report_drc -name RIS_board16_DRC_$tag -file $ris_reports/drc.rpt
        report_route_status -file $ris_reports/route_status.rpt
        report_io -file $ris_reports/io.rpt
        report_timing_summary -max_paths 20 -name RIS_board16_timing_$tag -file $ris_reports/timing.rpt
        set f [open $ris_reports/timing.rpt]; set timing [read $f]; close $f
        if {![string match {*All user specified timing constraints are met.*} $timing]} {
            error "Project Mode routed timing failed; design/reports retained for inspection"
        }
        set severe [get_drc_violations -quiet -filter {SEVERITY == Error || SEVERITY == {Critical Warning}}]
        if {[llength $severe]} {error "Project Mode DRC failed: $severe"}
        status "PASS: synth_1 and impl_1 complete; routed design and named reports open"
    }
    proc poll {} {
        variable ris_phase
        variable ris_timer
        if {[catch {
            set schedule_next 1
            set run [expr {$ris_phase eq "synth" ? "synth_1" : "impl_1"}]
            set run_status [get_property STATUS [get_runs $run]]
            status "$run: $run_status ([get_property PROGRESS [get_runs $run]])"
            if {[regexp -nocase {error|failed|cancelled} $run_status]} {
                error "$run stopped: $run_status"
            }
            if {[complete $run]} {
                if {$ris_phase eq "synth"} {
                    set ris_phase impl
                    if {![complete impl_1] || [get_property NEEDS_REFRESH [get_runs impl_1]]} {
                        launch_runs impl_1 -to_step route_design -jobs 2
                    }
                } else {
                    finish
                    set schedule_next 0
                }
            }
            if {$schedule_next} {set ris_timer [after 3000 ::ris_board_gui::poll]}
        } message]} {
            status "FAILED: $message"
            puts $::errorInfo
        }
    }
    proc start {} {
        variable ris_root
        variable ris_reports
        variable ris_phase
        variable ris_timer
        file mkdir $ris_reports
        if {$ris_timer ne {}} {after cancel $ris_timer}
        if {[current_project -quiet] eq {}} {
            open_project $ris_root/vivado_board/ris_ctrl_unit.xpr
        }
        if {[file normalize [get_property DIRECTORY [current_project]]] ne "$ris_root/vivado_board"} {
            error "Select vivado_board/ris_ctrl_unit.xpr before running this script"
        }
        set threads $ris_root/scripts/project_run_threads.tcl
        set_property STEPS.SYNTH_DESIGN.ARGS.DIRECTIVE RuntimeOptimized [get_runs synth_1]
        set_property STEPS.SYNTH_DESIGN.TCL.PRE $threads [get_runs synth_1]
        set_property STEPS.INIT_DESIGN.TCL.PRE $threads [get_runs impl_1]
        set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE Default [get_runs impl_1]
        set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
        set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE Default [get_runs impl_1]
        set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE Default [get_runs impl_1]
        set ris_phase synth
        if {[complete synth_1] && [get_property NEEDS_REFRESH [get_runs synth_1]]} {
            reset_runs synth_1
        }
        if {![complete synth_1]} {launch_runs synth_1 -jobs 2}
        status "Project Mode synthesis/implementation started"
        set ris_timer [after 1000 ::ris_board_gui::poll]
    }
}
::ris_board_gui::start
