# Run once against the existing PZ_UART design with Vivado 2020.2:
# vivado -mode batch -source scripts/build_rfmc6000_capture.tcl
# The source directory is resolved relative to this script, not the shell cwd.
set project_dir [file normalize [file join [file dirname [info script]] ..]]
if {[llength [get_projects -quiet]]} {close_project}
open_project [file join $project_dir PZ_UART.xpr]
set_property target_language Verilog [current_project]
set bd_file [get_files */design_1.bd]
open_bd_design $bd_file
if {[llength [get_bd_cells -quiet pl_ddr_mig]]} {
    error "The capture hardware already exists. Use the saved BD; do not rebuild over it."
}
# Discard only generated definitions from an interrupted capture build.
# Vivado 2020.2 otherwise reuses stale module-reference port metadata.
foreach module {rfmc_spi_io rfmc6000_rx rfmc_rx_pack rfmc_capture_axis} {
    file delete -force [file join $project_dir PZ_UART.srcs sources_1 bd mref $module]
}
update_ip_catalog -rebuild
foreach rtl {rfmc_spi_io.v rfmc6000_rx.v rfmc_rx_pack.v rfmc_capture_axis.v} {
    set f [file join $project_dir PZ_UART.srcs sources_1 new $rtl]
    if {![llength [get_files -quiet $f]]} {add_files -norecurse $f}
}
# ila_0 is already configured for global synthesis (module-reference-safe).
update_compile_order -fileset sources_1

proc ip {name type} {create_bd_cell -type ip -vlnv xilinx.com:ip:$type $name}
proc net {args} {
    set pins {}
    foreach p $args {lappend pins [get_bd_pins $p]}
    connect_bd_net {*}$pins
}
proc intf {a b} {connect_bd_intf_net [get_bd_intf_pins $a] [get_bd_intf_pins $b]}
proc expose {pin name} {
    make_bd_pins_external [get_bd_pins $pin]
    set p [get_bd_ports -of_objects [get_bd_nets -of_objects [get_bd_pins $pin]]]
    set_property name $name $p
    return $p
}

set ps [get_bd_cells processing_system7_0]
# The imported PS preset has 5 ns NAND tRC/tWC, which recompute to an
# illegal one-cycle value when any PS setting changes. Keep its peripheral
# routing intact and use legal 30 ns values so the customizer can validate.
set_property -dict [list CONFIG.PCW_USE_M_AXI_GP0 {1} \
    CONFIG.PCW_USE_M_AXI_GP1 {1} \
    CONFIG.PCW_NAND_CYCLES_T_RC {30} CONFIG.PCW_NAND_CYCLES_T_WC {30} \
    CONFIG.PCW_USE_S_AXI_HP0 {1} CONFIG.PCW_S_AXI_HP0_DATA_WIDTH {64} \
    CONFIG.PCW_SPI0_PERIPHERAL_ENABLE {1} CONFIG.PCW_SPI0_SPI0_IO {EMIO} \
    CONFIG.PCW_SPI0_GRP_SS0_ENABLE {1} CONFIG.PCW_SPI0_GRP_SS1_ENABLE {0} \
    CONFIG.PCW_SPI0_GRP_SS2_ENABLE {0} \
    CONFIG.PCW_GPIO_EMIO_GPIO_ENABLE {1} CONFIG.PCW_GPIO_EMIO_GPIO_IO {3} \
    CONFIG.PCW_USE_FABRIC_INTERRUPT {1} CONFIG.PCW_IRQ_F2P_INTR {1}] $ps

create_bd_cell -type module -reference rfmc_spi_io rfmc_spi_io_0
foreach {ps_pin bridge_pin} {
    SPI0_SCLK_O sclk_o SPI0_SCLK_T sclk_t SPI0_SCLK_I sclk_i
    SPI0_MOSI_O mosi_o SPI0_MOSI_T mosi_t SPI0_MOSI_I mosi_i
    SPI0_SS_O ss_o SPI0_SS_T ss_t SPI0_MISO_I miso_i
} {net processing_system7_0/$ps_pin rfmc_spi_io_0/$bridge_pin}
foreach p {rf_spi_sclk rf_spi_mosi rf_spi_miso rf_spi_csn} {
    expose rfmc_spi_io_0/$p $p
}
make_bd_intf_pins_external [get_bd_intf_pins processing_system7_0/GPIO_0]
set gpio_port [get_bd_intf_ports -of_objects [get_bd_intf_nets -of_objects [get_bd_intf_pins processing_system7_0/GPIO_0]]]
set_property name RF_CTRL $gpio_port

ip const0 xlconstant:1.1
set_property -dict [list CONFIG.CONST_WIDTH {1} CONFIG.CONST_VAL {0}] [get_bd_cells const0]
ip const1 xlconstant:1.1
set_property -dict [list CONFIG.CONST_WIDTH {1} CONFIG.CONST_VAL {1}] [get_bd_cells const1]
net const1/dout processing_system7_0/SPI0_SS_I
ip pl_clk_buf util_ds_buf:2.1
set_property CONFIG.C_BUF_TYPE IBUFDS [get_bd_cells pl_clk_buf]
set clk_p [expose pl_clk_buf/IBUF_DS_P sys_clk_p]
set clk_n [expose pl_clk_buf/IBUF_DS_N sys_clk_n]
set_property CONFIG.FREQ_HZ 200000000 $clk_p
set_property CONFIG.FREQ_HZ 200000000 $clk_n

ip pl_ddr_mig mig_7series:4.2
set_property CONFIG.XML_INPUT_FILE [file join $project_dir scripts mig pz7035_pl_ddr.prj] [get_bd_cells pl_ddr_mig]
make_bd_intf_pins_external [get_bd_intf_pins pl_ddr_mig/DDR3]
set ddr_port [get_bd_intf_ports -of_objects [get_bd_intf_nets -of_objects [get_bd_intf_pins pl_ddr_mig/DDR3]]]
set_property name PL_DDR3 $ddr_port
net pl_clk_buf/IBUF_OUT pl_ddr_mig/sys_clk_i pl_ddr_mig/clk_ref_i
net processing_system7_0/FCLK_RESET0_N pl_ddr_mig/sys_rst

foreach {name clock} {rst_ps processing_system7_0/FCLK_CLK0 rst_ref pl_clk_buf/IBUF_OUT rst_ui pl_ddr_mig/ui_clk} {
    ip $name proc_sys_reset:5.0
    set_property CONFIG.C_EXT_RESET_HIGH 0 [get_bd_cells $name]
    net $clock $name/slowest_sync_clk
    net processing_system7_0/FCLK_RESET0_N $name/ext_reset_in
    net const0/dout $name/mb_debug_sys_rst
    if {$name eq "rst_ui"} {
        net pl_ddr_mig/mmcm_locked $name/dcm_locked
        net pl_ddr_mig/ui_clk_sync_rst $name/aux_reset_in
    } else {
        net const1/dout $name/dcm_locked
        net const0/dout $name/aux_reset_in
    }
}
net rst_ui/peripheral_aresetn pl_ddr_mig/aresetn
net processing_system7_0/FCLK_CLK0 processing_system7_0/M_AXI_GP0_ACLK processing_system7_0/M_AXI_GP1_ACLK
net pl_ddr_mig/ui_clk processing_system7_0/S_AXI_HP0_ACLK

ip capture_dma axi_dma:7.1
set_property -dict [list CONFIG.c_include_mm2s {0} CONFIG.c_include_s2mm {1} \
    CONFIG.c_include_sg {1} CONFIG.c_sg_include_stscntrl_strm {0} \
    CONFIG.c_sg_length_width {26} CONFIG.c_m_axi_s2mm_data_width {64} \
    CONFIG.c_s_axis_s2mm_tdata_width {64} CONFIG.c_s2mm_burst_size {64} \
    CONFIG.c_prmry_is_aclk_async {1}] [get_bd_cells capture_dma]
ip readback_cdma axi_cdma:4.1
set_property -dict [list CONFIG.C_INCLUDE_SG {0} CONFIG.C_M_AXI_DATA_WIDTH {64} \
    CONFIG.C_M_AXI_MAX_BURST_LEN {64} CONFIG.C_AXI_LITE_IS_ASYNC {1}] [get_bd_cells readback_cdma]
ip capture_control axi_gpio:2.0
set_property -dict [list CONFIG.C_IS_DUAL {1} CONFIG.C_GPIO_WIDTH {32} \
    CONFIG.C_GPIO2_WIDTH {32} CONFIG.C_ALL_OUTPUTS {1} CONFIG.C_ALL_OUTPUTS_2 {1}] [get_bd_cells capture_control]
ip capture_status axi_gpio:2.0
set_property -dict [list CONFIG.C_GPIO_WIDTH {32} CONFIG.C_ALL_INPUTS {1}] [get_bd_cells capture_status]
ip sg_bram_ctrl axi_bram_ctrl:4.1
set_property -dict [list CONFIG.SINGLE_PORT_BRAM {1} CONFIG.DATA_WIDTH {32}] [get_bd_cells sg_bram_ctrl]
ip sg_bram blk_mem_gen:8.4
set_property -dict [list CONFIG.Memory_Type {Single_Port_RAM} \
    CONFIG.use_bram_block {BRAM_Controller} CONFIG.Enable_32bit_Address {true} \
    CONFIG.Write_Width_A {32} CONFIG.Write_Depth_A {16384} \
    CONFIG.Use_Byte_Write_Enable {true} CONFIG.Byte_Size {8}] [get_bd_cells sg_bram]
intf sg_bram_ctrl/BRAM_PORTA sg_bram/BRAM_PORTA

# One fabric provides GP control/direct PL DDR reads, S2MM writes, BRAM
# descriptor fetches, and CDMA PL DDR -> PS HP readback. Clock converters
# and data/protocol converters are generated at the heterogeneous ports.
ip capture_fabric axi_interconnect:2.1
set_property -dict [list CONFIG.NUM_SI {5} CONFIG.NUM_MI {7}] [get_bd_cells capture_fabric]
foreach {a b} {
    processing_system7_0/M_AXI_GP0 capture_fabric/S00_AXI
    processing_system7_0/M_AXI_GP1 capture_fabric/S04_AXI
    capture_dma/M_AXI_S2MM capture_fabric/S01_AXI
    capture_dma/M_AXI_SG capture_fabric/S02_AXI
    readback_cdma/M_AXI capture_fabric/S03_AXI
    capture_fabric/M00_AXI pl_ddr_mig/S_AXI
    capture_fabric/M01_AXI processing_system7_0/S_AXI_HP0
    capture_fabric/M02_AXI sg_bram_ctrl/S_AXI
    capture_fabric/M03_AXI capture_dma/S_AXI_LITE
    capture_fabric/M04_AXI readback_cdma/S_AXI_LITE
    capture_fabric/M05_AXI capture_control/S_AXI
    capture_fabric/M06_AXI capture_status/S_AXI
} {intf $a $b}
net pl_ddr_mig/ui_clk capture_fabric/ACLK capture_dma/m_axi_s2mm_aclk \
    capture_dma/m_axi_sg_aclk readback_cdma/m_axi_aclk sg_bram_ctrl/s_axi_aclk
net processing_system7_0/FCLK_CLK0 capture_dma/s_axi_lite_aclk \
    readback_cdma/s_axi_lite_aclk capture_control/s_axi_aclk capture_status/s_axi_aclk
net rst_ui/peripheral_aresetn capture_fabric/ARESETN \
    readback_cdma/axi_resetn sg_bram_ctrl/s_axi_aresetn
net rst_ps/peripheral_aresetn capture_dma/axi_resetn capture_control/s_axi_aresetn capture_status/s_axi_aresetn
foreach p {S00 S04 M03 M04 M05 M06} {
    net processing_system7_0/FCLK_CLK0 capture_fabric/${p}_ACLK
    net rst_ps/peripheral_aresetn capture_fabric/${p}_ARESETN
}
foreach p {S01 S02 S03 M00 M01 M02} {
    net pl_ddr_mig/ui_clk capture_fabric/${p}_ACLK
    net rst_ui/peripheral_aresetn capture_fabric/${p}_ARESETN
}

create_bd_cell -type module -reference rfmc6000_rx rfmc6000_rx_0
create_bd_cell -type module -reference rfmc_rx_pack rfmc_rx_pack_0
create_bd_cell -type module -reference rfmc_capture_axis rfmc_capture_axis_0
foreach p {rx_clk_p rx_clk_n rx_frame_in_p rx_frame_in_n rx_data_in_p rx_data_in_n} {
    expose rfmc6000_rx_0/$p $p
}
net pl_clk_buf/IBUF_OUT rfmc6000_rx_0/clk200
net rst_ref/peripheral_aresetn rfmc6000_rx_0/rstn
net capture_control/gpio_io_o rfmc6000_rx_0/control rfmc_capture_axis_0/control
net capture_control/gpio2_io_o rfmc_capture_axis_0/sample_count
net rfmc6000_rx_0/data_clk rfmc_rx_pack_0/adc_clk
net rfmc6000_rx_0/rx_resetn rfmc_rx_pack_0/adc_resetn
foreach {a b} {adc_valid adc_valid adc_status adc_status delay_ready delay_ready \
    adc_data_i1 adc_i1 adc_data_q1 adc_q1 adc_data_i2 adc_i2 adc_data_q2 adc_q2} {
    net rfmc6000_rx_0/$a rfmc_rx_pack_0/$b
}
ip rx_async_fifo axis_data_fifo:2.0
set_property -dict [list CONFIG.TDATA_NUM_BYTES {8} CONFIG.FIFO_DEPTH {16384} \
    CONFIG.IS_ACLK_ASYNC {1} CONFIG.FIFO_MEMORY_TYPE {block} \
    CONFIG.HAS_TLAST {0} CONFIG.HAS_TKEEP {0}] [get_bd_cells rx_async_fifo]
intf rfmc_rx_pack_0/M_AXIS rx_async_fifo/S_AXIS
intf rx_async_fifo/M_AXIS rfmc_capture_axis_0/S_AXIS
intf rfmc_capture_axis_0/M_AXIS capture_dma/S_AXIS_S2MM
net rfmc6000_rx_0/data_clk rx_async_fifo/s_axis_aclk
net rfmc6000_rx_0/rx_resetn rx_async_fifo/s_axis_aresetn
net pl_ddr_mig/ui_clk rx_async_fifo/m_axis_aclk rfmc_capture_axis_0/aclk
net rst_ui/peripheral_aresetn rfmc_capture_axis_0/aresetn
net processing_system7_0/FCLK_CLK0 rfmc_capture_axis_0/status_clk
net rst_ps/peripheral_aresetn rfmc_capture_axis_0/status_resetn
net pl_ddr_mig/init_calib_complete rfmc_capture_axis_0/mig_ready
net rfmc_rx_pack_0/overflow rfmc_capture_axis_0/rx_overflow
net rfmc_rx_pack_0/frame_error rfmc_capture_axis_0/rx_frame_error
net rfmc6000_rx_0/delay_ready rfmc_capture_axis_0/rx_delay_ready
net rfmc_capture_axis_0/status capture_status/gpio_io_i

ip capture_irq xlconcat:2.1
set_property CONFIG.NUM_PORTS 2 [get_bd_cells capture_irq]
net capture_dma/s2mm_introut capture_irq/In0
net readback_cdma/cdma_introut capture_irq/In1
net capture_irq/dout processing_system7_0/IRQ_F2P

# CPU can directly access the whole 1 GiB PL DDR window.
assign_bd_address -offset 0x80000000 -range 0x40000000 \
    -target_address_space [get_bd_addr_spaces processing_system7_0/Data] \
    [get_bd_addr_segs pl_ddr_mig/memmap/memaddr]
assign_bd_address -offset 0x80000000 -range 0x40000000 \
    -target_address_space [get_bd_addr_spaces capture_dma/Data_S2MM] \
    [get_bd_addr_segs pl_ddr_mig/memmap/memaddr]
assign_bd_address -offset 0x80000000 -range 0x40000000 \
    -target_address_space [get_bd_addr_spaces readback_cdma/Data] \
    [get_bd_addr_segs pl_ddr_mig/memmap/memaddr]
foreach {cell offset} {capture_dma 0x40400000 readback_cdma 0x40410000 \
    capture_control 0x41200000 capture_status 0x41210000} {
    assign_bd_address -offset $offset -range 0x10000 \
        -target_address_space [get_bd_addr_spaces processing_system7_0/Data] \
        [get_bd_addr_segs $cell/S_AXI*/*]
}
foreach master {processing_system7_0/Data capture_dma/Data_SG} {
    assign_bd_address -offset 0x42000000 -range 0x10000 \
        -target_address_space [get_bd_addr_spaces $master] \
        [get_bd_addr_segs sg_bram_ctrl/S_AXI/Mem0]
}
assign_bd_address -offset 0 -range 0x40000000 \
    -target_address_space [get_bd_addr_spaces readback_cdma/Data] \
    [get_bd_addr_segs processing_system7_0/S_AXI_HP0/HP0_DDR_LOWOCM]
# Unreachable/unneeded targets are explicitly excluded per master.
set targets [concat [get_bd_addr_segs pl_ddr_mig/memmap/memaddr] \
    [get_bd_addr_segs sg_bram_ctrl/S_AXI/Mem0] \
    [get_bd_addr_segs capture_dma/S_AXI_LITE/Reg] \
    [get_bd_addr_segs readback_cdma/S_AXI_LITE/Reg] \
    [get_bd_addr_segs capture_control/S_AXI/Reg] \
    [get_bd_addr_segs capture_status/S_AXI/Reg] \
    [get_bd_addr_segs processing_system7_0/S_AXI_HP0/*]]
foreach master {processing_system7_0/Data capture_dma/Data_S2MM capture_dma/Data_SG readback_cdma/Data} {
    foreach seg $targets {
        set keep 0
        if {$master eq "processing_system7_0/Data"} {
            set keep [expr {![string match */S_AXI_HP0/* $seg]}]
        } elseif {$master eq "capture_dma/Data_S2MM"} {
            set keep [string match */pl_ddr_mig/memmap/memaddr $seg]
        } elseif {$master eq "capture_dma/Data_SG"} {
            set keep [string match */sg_bram_ctrl/S_AXI/Mem0 $seg]
        } else {
            set keep [expr {[string match */pl_ddr_mig/memmap/memaddr $seg] ||
                [string match */S_AXI_HP0/HP0_DDR_LOWOCM $seg]}]
        }
        if {!$keep} {
            exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces $master] $seg
        }
    }
}

validate_bd_design
regenerate_bd_layout
save_bd_design
set xdc [file join $project_dir PZ_UART.srcs constrs_1 new rfmc6000_pl_ddr.xdc]
if {![llength [get_files -quiet $xdc]]} {add_files -fileset constrs_1 -norecurse $xdc}
generate_target all $bd_file
make_wrapper -files $bd_file -top
set_property top design_1_wrapper [get_filesets sources_1]
update_compile_order -fileset sources_1
write_bd_tcl -force [file join $project_dir scripts design_1_capture_export.tcl]
puts "CAPTURE_BD_BUILD_OK"
