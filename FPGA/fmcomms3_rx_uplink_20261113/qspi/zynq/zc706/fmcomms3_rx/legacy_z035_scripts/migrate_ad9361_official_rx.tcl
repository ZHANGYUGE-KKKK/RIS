# Prepare the current project/BD with the official ADI receiver and AXIS adapter.
# Does not replace board pin assignments, RIS logic, DMA data path or MIG.
set adi_root [file normalize [file join [file dirname [info script]] ..]]
if {[current_project -quiet] eq ""} {open_project $adi_root/PZ_UART.xpr}
if {[file normalize [get_property DIRECTORY [current_project]]] ne $adi_root} {error "Unexpected project"}
catch {close_hw_manager}
catch {close_design}
set adi_vendor $adi_root/PZ_UART.srcs/sources_1/adi_hdl
set adi_sources [concat [glob $adi_vendor/library/common/*.v] [glob $adi_vendor/library/xilinx/common/*.v] [glob $adi_vendor/library/axi_ad9361/*.v] [glob $adi_vendor/library/axi_ad9361/xilinx/*.v] [list $adi_root/PZ_UART.srcs/sources_1/new/ad9361_rx_lvds_if.v $adi_root/PZ_UART.srcs/sources_1/new/ad9361_rx_axis.v]]
foreach adi_file $adi_sources {
    if {[llength [get_files -quiet $adi_file]] == 0} {add_files -norecurse $adi_file}
}
foreach adi_legacy {*rfmc6000_iq_axis_cdc.xdc *rfmc6000_iq_axis_ila.xdc} {
    set adi_old [get_files -quiet $adi_legacy]
    if {[llength $adi_old]} {set_property IS_ENABLED false $adi_old}
}
foreach {adi_file adi_scope adi_late} [list \
    $adi_root/PZ_UART.srcs/constrs_1/new/ad9361_rx_cdc.xdc ad9361_rx_axis 0 \
    $adi_vendor/library/xilinx/common/ad_rst_constr.xdc ad_rst 0 \
    $adi_vendor/library/xilinx/common/up_xfer_cntrl_constr.xdc up_xfer_cntrl 0 \
    $adi_vendor/library/xilinx/common/up_xfer_status_constr.xdc up_xfer_status 0 \
    $adi_vendor/library/xilinx/common/up_clock_mon_constr.xdc up_clock_mon 0 \
    $adi_root/PZ_UART.srcs/constrs_1/new/ad9361_rx_ila.xdc {} 1] {
    if {[llength [get_files -quiet $adi_file]] == 0} {add_files -fileset constrs_1 -norecurse $adi_file}
    set adi_obj [get_files $adi_file]
    set_property USED_IN_SYNTHESIS false $adi_obj
    set_property USED_IN_IMPLEMENTATION true $adi_obj
    if {$adi_scope ne ""} {set_property SCOPED_TO_REF $adi_scope $adi_obj}
    if {$adi_late} {set_property PROCESSING_ORDER LATE $adi_obj}
}
set_property XPM_LIBRARIES {XPM_CDC XPM_FIFO XPM_MEMORY} [current_project]
update_compile_order -fileset sources_1
open_bd_design [get_files */design_1.bd]
if {[llength [get_bd_cells -quiet ad9361_rx_axis_0]] == 0} {
    set adi_new [create_bd_cell -type module -reference ad9361_rx_axis ad9361_rx_axis_0]
    set adi_old [get_bd_cells rfmc6000_iq_axis_0]
    foreach adi_pin [get_bd_pins -of_objects $adi_old] {
        set adi_net [get_bd_nets -quiet -of_objects $adi_pin]
        if {[llength $adi_net]} {
            set adi_name [file tail [get_property NAME $adi_pin]]
            set adi_target [get_bd_pins -quiet ad9361_rx_axis_0/$adi_name]
            if {[llength $adi_target] != 1} {error "Missing replacement pin $adi_name"}
            disconnect_bd_net $adi_net $adi_pin
            connect_bd_net -net [get_property NAME $adi_net] $adi_target
        }
    }
    set adi_axis_net [get_bd_intf_nets -of_objects [get_bd_intf_pins rfmc6000_iq_axis_0/M_AXIS]]
    delete_bd_objs $adi_axis_net
    connect_bd_intf_net [get_bd_intf_pins ad9361_rx_axis_0/M_AXIS] [get_bd_intf_pins axis_data_fifo_0/S_AXIS]
    delete_bd_objs $adi_old
} else {
    update_module_reference [get_ips design_1_ad9361_rx_axis_0_0]
}
set_property CONFIG.NUM_MI 4 [get_bd_cells axi_interconnect_1]
if {[llength [get_bd_intf_nets -quiet -of_objects [get_bd_intf_pins ad9361_rx_axis_0/S_AXI]]] == 0} {
    connect_bd_intf_net [get_bd_intf_pins axi_interconnect_1/M03_AXI] [get_bd_intf_pins ad9361_rx_axis_0/S_AXI]
}
if {[llength [get_bd_nets -quiet -of_objects [get_bd_pins axi_interconnect_1/M03_ACLK]]] == 0} {
    connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins axi_interconnect_1/M03_ACLK]
}
if {[llength [get_bd_nets -quiet -of_objects [get_bd_pins axi_interconnect_1/M03_ARESETN]]] == 0} {
    connect_bd_net [get_bd_pins rst_ps_fclk0/peripheral_aresetn] [get_bd_pins axi_interconnect_1/M03_ARESETN]
}
assign_bd_address -force -offset 0x82000000 -range 0x00010000 \
    -target_address_space [get_bd_addr_spaces processing_system7_0/Data] \
    [get_bd_addr_segs -of_objects [get_bd_intf_pins ad9361_rx_axis_0/S_AXI]]
validate_bd_design
save_bd_design
generate_target all [get_files */design_1.bd]
make_wrapper -files [get_files */design_1.bd] -top -force
puts AD9361_OFFICIAL_RX_BD_READY
