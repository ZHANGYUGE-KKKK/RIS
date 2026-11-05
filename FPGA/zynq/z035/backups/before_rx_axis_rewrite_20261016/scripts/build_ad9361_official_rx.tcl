# Vivado GUI: prepare official receiver, build, check timing, export BIT/LTX/XSA.
set adi_root [file normalize [file join [file dirname [info script]] ..]]
set adi_status $adi_root/reports/ad9361_official_port/build_status.txt
set adi_fd [open $adi_status w];puts $adi_fd "START [clock format [clock seconds]]";close $adi_fd
if {[catch {
    source $adi_root/scripts/migrate_ad9361_official_rx.tcl
    source $adi_root/scripts/rebuild_export_current.tcl
    set adi_clk [get_clocks -of_objects [get_pins ila_ad9361_rx/clk]]
    if {[llength $adi_clk] != 1 || abs([get_property PERIOD $adi_clk]-5.0)>0.001} {error "Receiver ILA must use 200 MHz"}
    write_debug_probes -force $adi_root/PZ_UART.runs/impl_1/pz7035_top.ltx
    report_io -file $ris_reports/io.rpt
    report_clock_interaction -file $ris_reports/clock_interaction.rpt
    set adi_fd [open $adi_status a]
    puts $adi_fd "PASS [clock format [clock seconds]]\nREPORTS=$ris_reports\nXSA=$ris_xsa\nADI_RX=0x82000000; ILA=200MHz"
    close $adi_fd
    puts AD9361_OFFICIAL_BUILD_PASS
} adi_error adi_opts]} {
    set adi_fd [open $adi_status a];puts $adi_fd "FAIL $adi_error\n[dict get $adi_opts -errorinfo]";close $adi_fd
    error $adi_error
}
