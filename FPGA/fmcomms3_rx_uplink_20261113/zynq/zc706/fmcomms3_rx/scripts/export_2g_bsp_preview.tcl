set root [file normalize [file join [file dirname [info script]] ..]]
if {[llength $argv]} {
    set report [file normalize [lindex $argv 0]]
} else {
    set f [open $root/reports/mig2g_active.txt];set report [string trim [read $f]];close $f
}
open_project $root/vivado/PZ_UART.xpr
write_hw_platform -fixed -force -file $report/bsp_preview.xsa
close_project
puts RX_DDR2G_BSP_PREVIEW_READY
exit
