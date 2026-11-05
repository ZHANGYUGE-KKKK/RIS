# Vivado reports an error when asked to reconnect an already joined net.
proc ddr2g_join {args} {
    set nets {}
    foreach object $args {
        set net [get_bd_nets -quiet -of_objects $object]
        if {![llength $net]} {connect_bd_net {*}$args;return}
        lappend nets $net
    }
    if {[llength [lsort -unique $nets]]>1} {connect_bd_net {*}$args}
}
# Source with design_1 open. Physical memory is 2GiB; the existing PS/DMA
# 0x40000000..0x7fffffff aperture remains 1GiB for the IQ fault comparison.
set_property CONFIG.FREQ_HZ 200000000 [get_bd_intf_ports sys_clk]
set mig [get_bd_cells mig_7series_0]
set_property CONFIG.BOARD_MIG_PARAM Custom $mig
set_property CONFIG.RESET_BOARD_INTERFACE Custom $mig
set_property CONFIG.XML_INPUT_FILE $root/constraints/zc706_mig.prj $mig
if {![llength [get_bd_cells -quiet mig2g_clock]]} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 mig2g_clock
}
set_property -dict [list CONFIG.PRIM_IN_FREQ 200 CONFIG.CLKOUT1_REQUESTED_OUT_FREQ 166.666667 \
    CONFIG.USE_RESET true CONFIG.RESET_TYPE ACTIVE_LOW CONFIG.USE_LOCKED true] [get_bd_cells mig2g_clock]
foreach pin {mig_7series_0/sys_clk_i mig_7series_0/sys_rst ad9361_rx_axis_0/ref_clk200} {
    set endpoint [get_bd_pins $pin]
    set net [get_bd_nets -quiet -of_objects $endpoint]
    if {[llength $net]} {disconnect_bd_net $net $endpoint}
}
ddr2g_join [get_bd_pins util_ds_buf_0/IBUF_OUT] [get_bd_pins mig2g_clock/clk_in1] [get_bd_pins ad9361_rx_axis_0/ref_clk200]
ddr2g_join [get_bd_ports rstn] [get_bd_pins mig2g_clock/resetn]
ddr2g_join [get_bd_pins mig2g_clock/clk_out1] [get_bd_pins mig_7series_0/sys_clk_i]
if {![llength [get_bd_cells -quiet mig2g_reset_gate]]} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 mig2g_reset_gate
}
set_property -dict [list CONFIG.C_SIZE 1 CONFIG.C_OPERATION and] [get_bd_cells mig2g_reset_gate]
ddr2g_join [get_bd_ports rstn] [get_bd_pins mig2g_reset_gate/Op1]
ddr2g_join [get_bd_pins mig2g_clock/locked] [get_bd_pins mig2g_reset_gate/Op2]
ddr2g_join [get_bd_pins mig2g_reset_gate/Res] [get_bd_pins mig_7series_0/sys_rst]
# Observe reset/calibration levels in the ILA's board200 domain through XPM.
if {![llength [get_files -quiet */ddr_status_cdc.v]]} {
    add_files -norecurse $root/PZ_UART.srcs/sources_1/new/ddr_status_cdc.v
}
if {![llength [get_bd_cells -quiet ddr_status_monitor]]} {
    create_bd_cell -type module -reference ddr_status_cdc ddr_status_monitor
}
ddr2g_join [get_bd_pins util_ds_buf_0/IBUF_OUT] [get_bd_pins ddr_status_monitor/clk200]
foreach {source input probe output} {
    mig_7series_0/ui_clk_sync_rst in_ui_reset 0 out_ui_reset
    proc_sys_reset_ddr/peripheral_aresetn in_resetn 1 out_resetn
    mig_7series_0/mmcm_locked in_mmcm_locked 2 out_mmcm_locked
    mig_7series_0/init_calib_complete in_calib 3 out_calib
} {
    set endpoint [get_bd_pins ila_ddr/probe$probe]
    set net [get_bd_nets -quiet -of_objects $endpoint]
    if {[llength $net]} {disconnect_bd_net $net $endpoint}
    connect_bd_net [get_bd_pins $source] [get_bd_pins ddr_status_monitor/$input]
    connect_bd_net [get_bd_pins ddr_status_monitor/$output] $endpoint
}
puts "DDR2G: dual rank DDR3-1333, UI166.667MHz; receiver IDELAY reference remains board200MHz"
