# Proposed memory/settings plan for the currently open design_1 BD.
# Both DMA masters access the existing PL MIG at the same physical address
# used by the PS. Descriptor/data partitioning is a software allocation.
# This script does not add wires, change existing PS/GPIO addresses, save
# the BD, generate a wrapper, or build a bitstream.
foreach ris_cell {axi_dma_0 axis_data_fifo_0 mig_7series_0} {
    if {[llength [get_bd_cells -quiet $ris_cell]] != 1} {
        error "Expected BD cell $ris_cell; open the current design_1 first"
    }
}
set_property -dict [list \
    CONFIG.c_m_axi_s2mm_data_width 64 \
    CONFIG.c_s_axis_s2mm_tdata_width 64 \
    CONFIG.c_sg_length_width 23] [get_bd_cells axi_dma_0]
set_property -dict [list \
    CONFIG.TDATA_NUM_BYTES 8 CONFIG.HAS_TKEEP 1 CONFIG.HAS_TLAST 1 \
    CONFIG.IS_ACLK_ASYNC 0 CONFIG.FIFO_MODE 1 \
    CONFIG.FIFO_DEPTH 16384] [get_bd_cells axis_data_fifo_0]
set ris_mig_segment [get_bd_addr_segs -quiet mig_7series_0/memmap/memaddr]
if {[llength $ris_mig_segment] != 1} {error "MIG memory segment is missing"}
foreach ris_space_name {axi_dma_0/Data_SG axi_dma_0/Data_S2MM} {
    set ris_space [get_bd_addr_spaces -quiet $ris_space_name]
    if {[llength $ris_space] != 1} {error "DMA space $ris_space_name is missing"}
    assign_bd_address -force -offset 0x40000000 -range 0x40000000 \
        -target_address_space $ris_space $ris_mig_segment
}
validate_bd_design
puts "RFMC6000_DMA_MEMORY_PLAN_APPLIED: SG/S2MM MIG=0x40000000..0x7fffffff, stream=64, length=23, FIFO=16384"
