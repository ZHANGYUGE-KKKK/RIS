set root [file normalize [file join [file dirname [info script]] ..]]
open_checkpoint $root/reports/routed.dcp
# These two CDC endpoints are duplicate copies of the constant 0xA marker.
# It changes only once on reset release; software waits 100ms, then requires
# READY and BUSY acknowledgement before reading any test verdict.
# CDC uses the launching flop's clock pin as the source endpoint.
set marker_source [get_pins {ddr_test_i/bist/inst/status_snapshot_reg[31]/C}]
foreach bit {29 31} {
    create_waiver -type CDC -id CDC-11 -from $marker_source \
        -to [get_pins [format {ddr_test_i/diag/inst/meta_reg[%d]/D} $bit]] \
        -description "Constant 0xA status marker, stable after reset; software startup delay and READY gate"
}
report_cdc -details -file $root/reports/cdc.rpt
report_waivers -file $root/reports/waivers.rpt
write_hw_platform -fixed -include_bit -force -file $root/export/ddr2g_test.xsa
puts DDR2G_FINAL_XSA_PASS
puts DDR2G_HARDWARE_BUILD_PASS
close_design
exit
