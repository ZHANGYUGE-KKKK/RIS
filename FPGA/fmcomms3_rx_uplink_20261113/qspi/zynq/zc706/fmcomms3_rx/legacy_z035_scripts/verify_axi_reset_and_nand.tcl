source [file join [file dirname [info script]] verify_ps_nand_timing.tcl]
proc assert_reset_link {source destination} {
    set a [get_bd_nets -of_objects [get_bd_pins $source]]
    set b [get_bd_nets -of_objects [get_bd_pins $destination]]
    if {[llength $a] != 1 || $a ne $b} {error "Missing connection: $source -> $destination"}
}
assert_reset_link processing_system7_0/FCLK_CLK0 rst_ps_fclk0/slowest_sync_clk
assert_reset_link processing_system7_0/FCLK_RESET0_N rst_ps_fclk0/ext_reset_in
assert_reset_link rst_ps_fclk0/interconnect_aresetn axi_interconnect_0/S00_ARESETN
assert_reset_link mig_7series_0/ui_clk proc_sys_reset_0/slowest_sync_clk
assert_reset_link mig_7series_0/mmcm_locked proc_sys_reset_0/dcm_locked
assert_reset_link mig_7series_0/init_calib_complete proc_sys_reset_0/aux_reset_in
foreach {cell parameter expected} {
    rst_ps_fclk0 C_EXT_RESET_HIGH 0
    proc_sys_reset_0 C_EXT_RESET_HIGH 1
    proc_sys_reset_0 C_AUX_RESET_HIGH 0
} {
    if {[get_property CONFIG.$parameter [get_bd_cells $cell]] ne $expected} {
        error "Wrong polarity: $cell/$parameter"
    }
}
puts "AXI_RESET_REOPEN_VERIFY_OK"
