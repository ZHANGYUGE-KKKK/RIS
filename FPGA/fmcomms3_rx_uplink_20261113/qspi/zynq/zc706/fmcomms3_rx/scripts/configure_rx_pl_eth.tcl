# Source with receiver design_1 open in Vivado 2022.2.
# J18 (RTL8211FS) connects to GTX bank 111 channel 1 over SGMII.
namespace eval ris_pl_eth {
    proc wire {source destination} {
        set a [get_bd_pins $source]
        set b [get_bd_pins $destination]
        set an [get_bd_nets -quiet -of_objects $a]
        set bn [get_bd_nets -quiet -of_objects $b]
        if {[llength $an] && $an eq $bn} {return}
        if {[llength $bn]} {error "Destination $destination already has a different driver"}
        connect_bd_net $a $b
    }
    proc bus {source destination} {
        set a [get_bd_intf_pins $source]
        set b [get_bd_intf_pins $destination]
        set an [get_bd_intf_nets -quiet -of_objects $a]
        set bn [get_bd_intf_nets -quiet -of_objects $b]
        if {[llength $an] && $an eq $bn} {return}
        if {[llength $bn]} {error "Interface $destination already has a different connection"}
        connect_bd_intf_net $a $b
    }
    proc export_bus {pin name} {
        set p [get_bd_intf_pins $pin]
        set n [get_bd_intf_nets -quiet -of_objects $p]
        set ext [get_bd_intf_ports -quiet -of_objects $n]
        if {![llength $ext]} {
            make_bd_intf_pins_external $p
            set n [get_bd_intf_nets -of_objects $p]
            set ext [get_bd_intf_ports -of_objects $n]
        }
        if {[llength $ext] != 1} {error "Expected one external interface for $pin"}
        if {[string trimleft $ext /] ne $name} {set_property name $name $ext}
    }
    proc constant {name width value} {
        set c [get_bd_cells -quiet $name]
        if {![llength $c]} {set c [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 $name]}
        set_property -dict [list CONFIG.CONST_WIDTH $width CONFIG.CONST_VAL $value] $c
        return $c
    }
}


if {[get_property NAME [current_bd_design]] ne "design_1"} {
    error "Open the receiver design_1 before sourcing this script"
}
set ps [get_bd_cells processing_system7_0]
set old_fclk0 [get_property CONFIG.PCW_ACT_FPGA0_PERIPHERAL_FREQMHZ $ps]
set dma_irq [get_bd_nets -of_objects [get_bd_pins processing_system7_0/IRQ_F2P]]
if {[llength $dma_irq] != 1} {error "Missing original receiver DMA IRQ connection"}

# GEM1 remains an EMIO MAC. Its data clocks come from PCS/PMA GEM adaptation.
# I2C0 MIO50/51 controls PCA9548A(0x74), channel 4, then Si5324(0x68).
# MIO46 stays GPIO for PCA9548A RESET_B; automatic I2C reset is disabled.
set ps [get_bd_cells processing_system7_0]
set_property -dict [list \
    CONFIG.PCW_ENET1_PERIPHERAL_ENABLE 1 \
    CONFIG.PCW_ENET1_ENET1_IO EMIO \
    CONFIG.PCW_ENET1_GRP_MDIO_ENABLE 1 \
    CONFIG.PCW_ENET1_GRP_MDIO_IO EMIO \
    CONFIG.PCW_EN_CLK1_PORT 1 CONFIG.PCW_EN_RST1_PORT 1 \
    CONFIG.PCW_FPGA_FCLK1_ENABLE 1 CONFIG.PCW_FPGA1_PERIPHERAL_FREQMHZ 200 \
    CONFIG.PCW_FCLK_CLK1_BUF TRUE \
    CONFIG.PCW_GPIO_EMIO_GPIO_ENABLE 1 CONFIG.PCW_GPIO_EMIO_GPIO_IO 3 \
    CONFIG.PCW_GPIO_EMIO_GPIO_WIDTH 3 \
    CONFIG.PCW_I2C0_PERIPHERAL_ENABLE 1 CONFIG.PCW_I2C0_I2C0_IO {MIO 50 .. 51} \
    CONFIG.PCW_I2C_RESET_ENABLE 0 CONFIG.PCW_I2C0_RESET_ENABLE 0] $ps


# Keep GPIO_PS[0] for AD9361. The wrapper also exposes [1:2] for J18 resets.
ris_pl_eth::export_bus processing_system7_0/GPIO_0 GPIO_PS

set pcs [get_bd_cells -quiet eth1_pcs_pma]
if {![llength $pcs]} {
    set pcs [create_bd_cell -type ip -vlnv xilinx.com:ip:gig_ethernet_pcs_pma:16.2 eth1_pcs_pma]
}
set_property -dict [list \
    CONFIG.Standard SGMII CONFIG.Physical_Interface Transceiver \
    CONFIG.EMAC_IF_TEMAC GEM CONFIG.SupportLevel Include_Shared_Logic_in_Core \
    CONFIG.RefClkRate 125 CONFIG.RefClkSrc clk1 \
    CONFIG.Management_Interface true CONFIG.Ext_Management_Interface true \
    CONFIG.Auto_Negotiation true CONFIG.SGMII_PHY_Mode false \
    CONFIG.SGMII_Mode 10_100_1000 CONFIG.DrpClkRate 50.0] $pcs
# DrpClkRate is an UltraScale GUI field. Generated Zynq7 GTX startup FSM uses
# STABLE_CLOCK_PERIOD=5 ns, so independent_clock_bufg must remain 200 MHz.
ris_pl_eth::bus processing_system7_0/GMII_ETHERNET_1 eth1_pcs_pma/gmii_gem_pcs_pma
ris_pl_eth::bus processing_system7_0/MDIO_ETHERNET_1 eth1_pcs_pma/mdio_pcs_pma
ris_pl_eth::wire processing_system7_0/ENET1_MDIO_T eth1_pcs_pma/mdio_t_in
ris_pl_eth::export_bus eth1_pcs_pma/ext_mdio_pcs_pma pl_eth_mdio
ris_pl_eth::export_bus eth1_pcs_pma/sgmii pl_eth_sgmii
ris_pl_eth::export_bus eth1_pcs_pma/gtrefclk_in pl_eth_refclk
set_property CONFIG.FREQ_HZ 125000000 [get_bd_intf_ports pl_eth_refclk]

if {![llength [get_bd_cells -quiet reset_eth]]} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 reset_eth
}
ris_pl_eth::wire processing_system7_0/FCLK_CLK1 eth1_pcs_pma/independent_clock_bufg
ris_pl_eth::wire processing_system7_0/FCLK_CLK1 reset_eth/slowest_sync_clk
ris_pl_eth::wire processing_system7_0/FCLK_RESET1_N reset_eth/ext_reset_in
ris_pl_eth::constant eth1_const_high 1 1
ris_pl_eth::wire eth1_const_high/dout reset_eth/dcm_locked
ris_pl_eth::wire reset_eth/peripheral_reset eth1_pcs_pma/reset

# PCS address 8 is distinct from the schematic PHYAD strap 2 on U48.
# Use the MDIO registers for configuration; the alternate config write strobes
# are held low. MAC-side SGMII advertises its built-in 0x0001 AN word.
ris_pl_eth::constant eth1_pcs_address 5 8
ris_pl_eth::constant eth1_config_default 5 16
ris_pl_eth::constant eth1_an_default 16 1
ris_pl_eth::constant eth1_const_low 1 0
ris_pl_eth::wire eth1_pcs_address/dout eth1_pcs_pma/phyaddr
ris_pl_eth::wire eth1_config_default/dout eth1_pcs_pma/configuration_vector
ris_pl_eth::wire eth1_an_default/dout eth1_pcs_pma/an_adv_config_vector
foreach pin {configuration_valid an_adv_config_val an_restart_config} {
    ris_pl_eth::wire eth1_const_low/dout eth1_pcs_pma/$pin
}
ris_pl_eth::wire eth1_const_high/dout eth1_pcs_pma/signal_detect
# Copper PHY has no optical LOS signal; AN/link status is read over MDIO.
# PCS AN interrupt is intentionally polled. PS GEM packet interrupts stay in PS.

ris_pl_eth::wire eth1_const_low/dout processing_system7_0/ENET1_EXT_INTIN
validate_bd_design -force
if {[get_property CONFIG.PCW_ACT_FPGA0_PERIPHERAL_FREQMHZ $ps] != $old_fclk0} {
    error "Receiver FCLK0 frequency changed"
}
if {[get_property CONFIG.PCW_ACT_FPGA1_PERIPHERAL_FREQMHZ $ps] != 200.0} {
    error "PCS independent clock FCLK1 must remain 200 MHz"
}
if {[get_property CONFIG.C_EXT_RESET_HIGH [get_bd_cells reset_eth]] != 0} {
    error "Ethernet reset must accept active-low FCLK_RESET1_N"
}
if {[get_bd_nets -of_objects [get_bd_pins processing_system7_0/IRQ_F2P]] ne $dma_irq} {
    error "Receiver DMA IRQ connection changed"
}
save_bd_design
puts RECEIVER_GEM1_SGMII_BD_CONFIGURED
