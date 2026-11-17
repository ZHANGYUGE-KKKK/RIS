# Source with ris_system open in Vivado 2022.2.
# Vendor ZC706 schematic (1_四川真为电子_ZC706_SCH.pdf): J18 / U48 is
# RTL8211FS in UTP<->SGMII mode, wired to GTX bank 111 channel 1.
# This updates only the BD; top-level package pins belong in ris_pl_eth.xdc.
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
    proc remove_external_bus {name} {
        set p [get_bd_intf_ports -quiet $name]
        if {![llength $p]} {return}
        set n [get_bd_intf_nets -quiet -of_objects $p]
        if {[llength $n]} {delete_bd_objs $n}
        delete_bd_objs $p
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
    proc output_slice {name bit port} {
        set c [get_bd_cells -quiet $name]
        if {![llength $c]} {set c [create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 $name]}
        set_property -dict [list CONFIG.DIN_WIDTH 2 CONFIG.DIN_FROM $bit CONFIG.DIN_TO $bit CONFIG.DOUT_WIDTH 1] $c
        wire ps7/GPIO_O $name/Din
        set p [get_bd_ports -quiet $port]
        if {![llength $p]} {set p [create_bd_port -dir O -from 0 -to 0 $port]}
        set n [get_bd_nets -quiet -of_objects $p]
        set cn [get_bd_nets -quiet -of_objects [get_bd_pins $name/Dout]]
        if {[llength $n] && $n eq $cn} {return}
        if {[llength $n]} {disconnect_bd_net $n $p}
        connect_bd_net [get_bd_pins $name/Dout] $p
    }
}

if {[get_property NAME [current_bd_design]] ne "ris_system"} {
    error "Open ris_system before sourcing configure_pl_eth_bd.tcl"
}

# Retire the RGMII path: the vendor board does not route U48 RGMII to PL.
foreach name {pl_eth_rgmii GMII_ETHERNET_1_0 MDIO_ETHERNET_1_0} {
    ris_pl_eth::remove_external_bus $name
}
set old [get_bd_cells -quiet gmii_to_rgmii_0]
if {[llength $old]} {
    ris_pl_eth::remove_external_bus pl_eth_mdio
    set old_buses [get_bd_intf_nets -quiet -of_objects [get_bd_intf_pins -of_objects $old]]
    if {[llength $old_buses]} {delete_bd_objs $old_buses}
    delete_bd_objs $old
}

# GEM1 remains an EMIO MAC. Its data clocks come from PCS/PMA GEM adaptation.
# I2C0 MIO50/51 controls PCA9548A(0x74), channel 4, then Si5324(0x68).
# MIO46 stays GPIO for PCA9548A RESET_B; automatic I2C reset is disabled.
set ps [get_bd_cells ps7]
set_property -dict [list \
    CONFIG.PCW_ENET1_PERIPHERAL_ENABLE 1 \
    CONFIG.PCW_ENET1_ENET1_IO EMIO \
    CONFIG.PCW_ENET1_GRP_MDIO_ENABLE 1 \
    CONFIG.PCW_ENET1_GRP_MDIO_IO EMIO \
    CONFIG.PCW_EN_CLK1_PORT 1 CONFIG.PCW_EN_RST1_PORT 1 \
    CONFIG.PCW_FPGA_FCLK1_ENABLE 1 CONFIG.PCW_FPGA1_PERIPHERAL_FREQMHZ 200 \
    CONFIG.PCW_FCLK_CLK1_BUF TRUE \
    CONFIG.PCW_GPIO_EMIO_GPIO_ENABLE 1 CONFIG.PCW_GPIO_EMIO_GPIO_IO 2 \
    CONFIG.PCW_GPIO_EMIO_GPIO_WIDTH 2 \
    CONFIG.PCW_I2C0_PERIPHERAL_ENABLE 1 CONFIG.PCW_I2C0_I2C0_IO {MIO 50 .. 51} \
    CONFIG.PCW_I2C_RESET_ENABLE 0 CONFIG.PCW_I2C0_RESET_ENABLE 0] $ps

# Remove only the known obsolete, undriven EthernetLite interrupt concat.
set obsolete [get_bd_cells -quiet xlconcat_0]
if {[llength $obsolete]} {
    set inputs [get_bd_nets -quiet -of_objects [get_bd_pins xlconcat_0/In0]]
    if {[llength $inputs]} {error "xlconcat_0 has an active source; refusing to remove it"}
    set output [get_bd_nets -quiet -of_objects [get_bd_pins xlconcat_0/dout]]
    if {[llength $output]} {delete_bd_objs $output}
    delete_bd_objs $obsolete
}
set_property CONFIG.PCW_USE_FABRIC_INTERRUPT 0 $ps

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
ris_pl_eth::bus ps7/GMII_ETHERNET_1 eth1_pcs_pma/gmii_gem_pcs_pma
ris_pl_eth::bus ps7/MDIO_ETHERNET_1 eth1_pcs_pma/mdio_pcs_pma
ris_pl_eth::wire ps7/ENET1_MDIO_T eth1_pcs_pma/mdio_t_in
ris_pl_eth::export_bus eth1_pcs_pma/ext_mdio_pcs_pma pl_eth_mdio
ris_pl_eth::export_bus eth1_pcs_pma/sgmii pl_eth_sgmii
ris_pl_eth::export_bus eth1_pcs_pma/gtrefclk_in pl_eth_refclk
set_property CONFIG.FREQ_HZ 125000000 [get_bd_intf_ports pl_eth_refclk]

if {![llength [get_bd_cells -quiet reset_eth]]} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 reset_eth
}
ris_pl_eth::wire ps7/FCLK_CLK1 eth1_pcs_pma/independent_clock_bufg
ris_pl_eth::wire ps7/FCLK_CLK1 reset_eth/slowest_sync_clk
ris_pl_eth::wire ps7/FCLK_RESET1_N reset_eth/ext_reset_in
ris_pl_eth::wire constant_one/dout reset_eth/dcm_locked
ris_pl_eth::wire reset_eth/peripheral_reset eth1_pcs_pma/reset

# PCS address 8 is distinct from the schematic PHYAD strap 2 on U48.
# Use the MDIO registers for configuration; the alternate config write strobes
# are held low. MAC-side SGMII advertises its built-in 0x0001 AN word.
ris_pl_eth::constant eth1_pcs_address 5 8
ris_pl_eth::constant eth1_config_default 5 16
ris_pl_eth::constant eth1_an_default 16 1
ris_pl_eth::constant constant_zero 1 0
ris_pl_eth::wire eth1_pcs_address/dout eth1_pcs_pma/phyaddr
ris_pl_eth::wire eth1_config_default/dout eth1_pcs_pma/configuration_vector
ris_pl_eth::wire eth1_an_default/dout eth1_pcs_pma/an_adv_config_vector
foreach pin {configuration_valid an_adv_config_val an_restart_config} {
    ris_pl_eth::wire constant_zero/dout eth1_pcs_pma/$pin
}
ris_pl_eth::wire constant_one/dout eth1_pcs_pma/signal_detect
# Copper PHY has no optical LOS signal; AN/link status is read over MDIO.
# PCS AN interrupt is intentionally polled. PS GEM packet interrupts stay in PS.
set ext [get_bd_ports -quiet ENET1_EXT_INTIN_0]
if {[llength $ext]} {
    set net [get_bd_nets -quiet -of_objects $ext]
    if {[llength $net]} {delete_bd_objs $net}
    delete_bd_objs $ext
}
ris_pl_eth::wire constant_zero/dout ps7/ENET1_EXT_INTIN

# EMIO GPIO 54: U48 RESET_B (H14 via U70 level translator).
# EMIO GPIO 55: U60 Si5324 RST_B (W23). Firmware must release the clock device,
# program 125 MHz CKOUT2 over I2C, wait for stable refclk, then release the PHY.
ris_pl_eth::wire ps7/GPIO_O ps7/GPIO_I
ris_pl_eth::output_slice eth1_phy_reset_slice 0 pl_eth_reset_n
ris_pl_eth::output_slice eth1_clk_reset_slice 1 pl_eth_si5324_reset_n

validate_bd_design -force
if {[get_property CONFIG.PCW_ACT_FPGA0_PERIPHERAL_FREQMHZ $ps] != 100.0} {error "Original RIS FCLK0 must remain 100 MHz"}
if {[get_property CONFIG.PCW_ACT_FPGA1_PERIPHERAL_FREQMHZ $ps] != 200.0} {error "PCS independent clock FCLK1 must remain 200 MHz"}
if {[get_property CONFIG.C_EXT_RESET_HIGH [get_bd_cells reset_eth]] != 0} {error "Ethernet reset must accept active-low FCLK_RESET1_N"}
save_bd_design
puts RIS_PL_ETH_SGMII_BD_CONFIGURED
