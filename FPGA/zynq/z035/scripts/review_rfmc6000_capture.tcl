set project_dir [file normalize [file join [file dirname [info script]] ..]]
open_project [file join $project_dir PZ_UART.xpr]
open_bd_design [get_files */design_1.bd]
validate_bd_design
regenerate_bd_layout
save_bd_design
write_bd_tcl -force [file join $project_dir scripts design_1_capture_export.tcl]
puts "SYNTH_STATUS=[get_property STATUS [get_runs synth_1]]"
puts "SYNTH_NEEDS_REFRESH=[get_property NEEDS_REFRESH [get_runs synth_1]]"
puts "CAPTURE_FINAL_REVIEW_OK"
