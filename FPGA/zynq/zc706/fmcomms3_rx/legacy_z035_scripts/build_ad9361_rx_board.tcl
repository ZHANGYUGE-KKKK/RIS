# Build a private project snapshot, close timing, and publish matching
# BIT/LTX/XSA artifacts. Run in a separate Vivado batch process.
# No hardware connection or programming is performed by this script.
# Usage: vivado -mode batch -source scripts/build_ad9361_rx_board.tcl \
#        -tclargs /absolute/report/directory
set rx_board_root [file normalize [file join [file dirname [info script]] ..]]
if {[llength $argv] != 1} {error "Expected one report directory"}
set rx_board_reports [file normalize [lindex $argv 0]]
file mkdir $rx_board_reports
set rx_board_status $rx_board_reports/build_status.txt
set rx_board_fd [open $rx_board_status w]
puts $rx_board_fd "START [clock format [clock seconds]]"
close $rx_board_fd
set rx_board_rtl $rx_board_root/PZ_UART.srcs/sources_1/new/ad9361_rx_axis.v
set rx_board_source_hash [lindex [exec sha256sum $rx_board_rtl] 0]

if {[catch {
    set argv [list $rx_board_reports/synthesis]
    source $rx_board_root/scripts/verify_ad9361_rx_integration.tcl
    open_project $rx_copy_root/PZ_UART.xpr
    open_checkpoint $rx_board_reports/synthesis/pz7035_top_rewrite_synth.dcp
    opt_design
    write_checkpoint -force $rx_board_reports/pz7035_top_opt.dcp
    place_design -directive Explore
    phys_opt_design -directive Explore
    write_checkpoint -force $rx_board_reports/pz7035_top_placed.dcp
    route_design -directive Explore
    write_checkpoint -force $rx_board_reports/pz7035_top_routed.dcp
    report_timing_summary -max_paths 20 -file $rx_board_reports/timing_route.rpt
    report_bus_skew -file $rx_board_reports/bus_skew.rpt
    report_cdc -details -file $rx_board_reports/cdc.rpt
    report_drc -file $rx_board_reports/drc.rpt
    report_route_status -file $rx_board_reports/route_status.rpt
    report_utilization -hierarchical -file $rx_board_reports/utilization_route.rpt
    report_clock_interaction -file $rx_board_reports/clock_interaction.rpt
    report_io -file $rx_board_reports/io.rpt
    check_timing -verbose -file $rx_board_reports/check_timing.rpt

    set rx_board_fd [open $rx_board_reports/timing_route.rpt r]
    set rx_board_timing [read $rx_board_fd]
    close $rx_board_fd
    if {![string match {*All user specified timing constraints are met.*} $rx_board_timing]} {
        error "Routed timing did not close; review timing_route.rpt"
    }
    set rx_board_fd [open $rx_board_reports/cdc.rpt r]
    set rx_board_cdc [read $rx_board_fd]
    close $rx_board_fd
    if {[regexp -line {^CDC-[0-9]+[ \t]+Critical[ \t]+[1-9]} $rx_board_cdc]} {
        error "Critical CDC paths remain; review cdc.rpt"
    }
    set rx_board_fd [open $rx_board_reports/bus_skew.rpt r]
    set rx_board_skew [read $rx_board_fd]
    close $rx_board_fd
    if {[regexp -line {^\s+(Slow|Fast)\s+[0-9.]+\s+[0-9.]+\s+-[0-9.]+\s*$} $rx_board_skew]} {
        error "Bus skew violation remains; review bus_skew.rpt"
    }

    write_bitstream -force $rx_board_reports/pz7035_top.bit
    write_debug_probes -force $rx_board_reports/pz7035_top.ltx
    puts [exec python3 $rx_board_root/scripts/check_ad9361_rx_probes.py $rx_board_reports/pz7035_top.ltx]
    write_hw_platform -fixed -include_bit -force -file $rx_board_reports/pz7035_top.xsa
    if {[lindex [exec sha256sum $rx_board_rtl] 0] ne $rx_board_source_hash} {
        error "Receiver RTL changed during the build; artifacts retained in report directory but not published"
    }

    # Compare the complete BIT configuration payload and regenerated HWH.
    # Vivado may regenerate the BIT timestamp during XSA export; publish the
    # embedded BIT after validation so the external BIT and XSA match exactly.
    set rx_board_publish [exec python3 $rx_board_root/scripts/publish_ad9361_rx_board.py \
        $rx_board_root $rx_board_reports $rx_copy_root $rx_board_source_hash]
    puts "RX_BOARD_PUBLISHED=$rx_board_publish"
    set rx_board_fd [open $rx_board_status a]
    puts $rx_board_fd "PASS [clock format [clock seconds]]\nRTL_SHA256=$rx_board_source_hash\nREPORTS=$rx_board_reports\nXSA=$rx_board_root/pz7035_top.xsa"
    close $rx_board_fd
    puts "AD9361_RX_BOARD_BUILD_PASS=$rx_board_reports"
    close_project
} rx_board_error rx_board_options]} {
    set rx_board_fd [open $rx_board_status a]
    puts $rx_board_fd "FAIL [clock format [clock seconds]]\n$rx_board_error\n[dict get $rx_board_options -errorinfo]"
    close $rx_board_fd
    error $rx_board_error
}
