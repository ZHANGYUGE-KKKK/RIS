# Export PS metadata while physical implementation runs independently.
set root [file normalize [file join [file dirname [info script]] ..]]
file mkdir $root/build/board_v1
open_project $root/vivado_axi/ris_ctrl_unit.xpr
write_hw_platform -fixed -force -file $root/build/board_v1/bsp_preview.xsa
close_project
exit
