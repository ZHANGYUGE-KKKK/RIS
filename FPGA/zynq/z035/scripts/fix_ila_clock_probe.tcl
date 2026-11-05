# Preserve the external 200 MHz ILA clock. Replace only the clock-as-data probe.
set clock_probe_dir [file normalize [file join [file dirname [info script]] ..]]
if {[llength [get_projects -quiet]] == 0} {
    open_project [file join $clock_probe_dir PZ_UART.xpr]
} elseif {[file normalize [get_property DIRECTORY [current_project]]] ne $clock_probe_dir} {
    error "Open PZ_UART in $clock_probe_dir first."
}
set clock_probe_bd [get_files */design_1.bd]
open_bd_design $clock_probe_bd
set clock_probe_backup [file join $clock_probe_dir backups before_ila_clock_probe_fix_[clock format [clock seconds] -format %Y%m%d_%H%M%S]]
file mkdir $clock_probe_backup
file copy $clock_probe_bd [file join $clock_probe_backup design_1.bd]
file copy [file join $clock_probe_dir PZ_UART.xpr] $clock_probe_backup
set clock_probe_pin [get_bd_pins ila_ddr/probe1]
set clock_probe_source [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
set clock_probe_old [get_bd_nets -of_objects $clock_probe_pin]
set clock_probe_new [get_bd_nets -of_objects $clock_probe_source]
if {$clock_probe_old ne $clock_probe_new} {
    disconnect_bd_net $clock_probe_old $clock_probe_pin
    connect_bd_net $clock_probe_source $clock_probe_pin
}
validate_bd_design -force
save_bd_design
generate_target all $clock_probe_bd
puts "ILA_CLOCK_PROBE_REPLACED"
