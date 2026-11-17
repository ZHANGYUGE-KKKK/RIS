# Run from Vivado's Tcl console, or with vivado -mode batch -source this_file.
# This script only repairs the PS NAND read/write timing validation errors.
set nand_project_dir [file normalize [file join [file dirname [info script]] ..]]
set nand_project_file [file join $nand_project_dir PZ_UART.xpr]
if {[llength [get_projects -quiet]] == 0} {
    open_project $nand_project_file
} elseif {[file normalize [get_property DIRECTORY [current_project]]] ne $nand_project_dir} {
    error "Open PZ_UART.xpr in $nand_project_dir before running this script."
}
set nand_bd_file [get_files */design_1.bd]
if {[llength $nand_bd_file] != 1} {
    error "Expected exactly one design_1.bd."
}
open_bd_design $nand_bd_file
set nand_ps [get_bd_cells processing_system7_0]
set nand_backup_dir [file join $nand_project_dir backups before_nand_timing_fix_[clock format [clock seconds] -format %Y%m%d_%H%M%S]]
file mkdir $nand_backup_dir
file copy $nand_bd_file [file join $nand_backup_dir design_1.bd]
file copy $nand_project_file [file join $nand_backup_dir PZ_UART.xpr]

puts "NAND_TIMING_BEFORE: T_RC=[get_property CONFIG.PCW_NAND_CYCLES_T_RC $nand_ps] T_WC=[get_property CONFIG.PCW_NAND_CYCLES_T_WC $nand_ps] SMC_MHZ=[get_property CONFIG.PCW_ACT_SMC_PERIPHERAL_FREQMHZ $nand_ps]"
# These inputs are timing values in ns, despite their CYCLES parameter names.
# Vivado converts them to SMC clock cycles; 5 ns at 100 MHz gives only 1 cycle.
# 30 ns places both fields within the required 2..15 cycle range at 100 MHz.
# Actual NAND operation still requires timings from the fitted flash datasheet.
set_property -dict [list \
    CONFIG.PCW_NAND_CYCLES_T_RC {30} \
    CONFIG.PCW_NAND_CYCLES_T_WC {30} \
] $nand_ps
validate_bd_design
save_bd_design
generate_target all $nand_bd_file
puts "NAND_TIMING_AFTER: T_RC=[get_property CONFIG.PCW_NAND_CYCLES_T_RC $nand_ps] T_WC=[get_property CONFIG.PCW_NAND_CYCLES_T_WC $nand_ps] SMC_MHZ=[get_property CONFIG.PCW_ACT_SMC_PERIPHERAL_FREQMHZ $nand_ps]"
puts "NAND_TIMING_FIX_OK"
