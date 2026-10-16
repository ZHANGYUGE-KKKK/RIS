# Read the saved BD in a fresh Vivado process and force parameter propagation.
set nand_verify_dir [file normalize [file join [file dirname [info script]] ..]]
open_project [file join $nand_verify_dir PZ_UART.xpr]
open_bd_design [get_files */design_1.bd]
set nand_verify_ps [get_bd_cells processing_system7_0]
foreach nand_verify_field {PCW_NAND_CYCLES_T_RC PCW_NAND_CYCLES_T_WC} {
    set nand_verify_value [get_property CONFIG.$nand_verify_field $nand_verify_ps]
    if {$nand_verify_value ne "30"} {
        error "Saved $nand_verify_field is $nand_verify_value; expected 30."
    }
    puts "SAVED_NAND_TIMING: $nand_verify_field=$nand_verify_value"
}
validate_bd_design -force
puts "NAND_TIMING_REOPEN_VALIDATE_OK"
