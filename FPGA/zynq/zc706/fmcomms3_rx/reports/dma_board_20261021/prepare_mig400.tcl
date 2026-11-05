set root [file normalize [file join [file dirname [info script]] ../..]]
set trial $root/reports/dma_board_20261021/mig400_trial
file mkdir $trial
open_project $root/vivado/PZ_UART.xpr
save_project_as -force -exclude_run_results mig400 $trial/project
set bd [get_files */design_1.bd]
open_bd_design $bd
set mig [get_bd_cells mig_7series_0]
set_property CONFIG.BOARD_MIG_PARAM Custom $mig
set_property CONFIG.XML_INPUT_FILE $trial/mig400.prj $mig
set ref200 [get_bd_pins ad9361_rx_axis_0/ref_clk200]
disconnect_bd_net [get_bd_nets -of_objects $ref200] $ref200
connect_bd_net [get_bd_pins util_ds_buf_0/IBUF_OUT] $ref200
validate_bd_design
save_bd_design
set_property synth_checkpoint_mode None $bd
generate_target all $bd
update_compile_order -fileset sources_1
report_property $mig
close_project
puts MIG400_PREPARED
exit
