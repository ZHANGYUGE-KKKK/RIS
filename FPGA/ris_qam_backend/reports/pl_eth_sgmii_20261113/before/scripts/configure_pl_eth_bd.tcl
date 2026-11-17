# Source with ris_system open. Completes GEM1 EMIO -> RGMII in the current BD.
# No package-pin assignments, implementation, export of BIT/XSA, or programming.
namespace eval ris_pl_eth {
    proc wire {source destination} {
        set a [get_bd_pins $source]
        set b [get_bd_pins $destination]
        set an [get_bd_nets -quiet -of_objects $a]
        set bn [get_bd_nets -quiet -of_objects $b]
        if {[llength $an] && $an eq $bn} {return}
        connect_bd_net $a $b
    }
    proc bus {source destination} {
        set a [get_bd_intf_pins $source]
        set b [get_bd_intf_pins $destination]
        set an [get_bd_intf_nets -quiet -of_objects $a]
        set bn [get_bd_intf_nets -quiet -of_objects $b]
        if {[llength $an] && $an eq $bn} {return}
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
}

if {[get_property NAME [current_bd_design]] ne "ris_system"} {
    error "Open ris_system before sourcing configure_pl_eth_bd.tcl"
}
set ps [get_bd_cells ps7]
set_property -dict [list \
    CONFIG.PCW_ENET1_PERIPHERAL_ENABLE 1 \
    CONFIG.PCW_ENET1_ENET1_IO EMIO \
    CONFIG.PCW_ENET1_GRP_MDIO_ENABLE 1 \
    CONFIG.PCW_ENET1_GRP_MDIO_IO EMIO \
    CONFIG.PCW_EN_CLK1_PORT 1 \
    CONFIG.PCW_EN_RST1_PORT 1 \
    CONFIG.PCW_FPGA_FCLK1_ENABLE 1 \
    CONFIG.PCW_FPGA1_PERIPHERAL_FREQMHZ 200 \
    CONFIG.PCW_FCLK_CLK1_BUF TRUE \
    CONFIG.PCW_GPIO_EMIO_GPIO_ENABLE 1 \
    CONFIG.PCW_GPIO_EMIO_GPIO_IO 1 \
    CONFIG.PCW_GPIO_EMIO_GPIO_WIDTH 1] $ps

# Retire the disconnected EthernetLite interrupt concat. GEM1 uses its PS IRQ.
set obsolete [get_bd_cells -quiet xlconcat_0]
if {[llength $obsolete]} {
    set inputs [get_bd_nets -quiet -of_objects [get_bd_pins xlconcat_0/In0]]
    if {[llength $inputs]} {error "xlconcat_0 has an active source; refusing to remove it"}
    set output [get_bd_nets -quiet -of_objects [get_bd_pins xlconcat_0/dout]]
    if {[llength $output]} {delete_bd_objs $output}
    delete_bd_objs $obsolete
}
set_property CONFIG.PCW_USE_FABRIC_INTERRUPT 0 $ps

set converter [get_bd_cells -quiet gmii_to_rgmii_0]
if {![llength $converter]} {
    set converter [create_bd_cell -type ip -vlnv xilinx.com:ip:gmii_to_rgmii:4.1 gmii_to_rgmii_0]
}
set_property -dict [list \
    CONFIG.SupportLevel Include_Shared_Logic_in_Core \
    CONFIG.C_EXTERNAL_CLOCK false \
    CONFIG.C_USE_IDELAY_CTRL true \
    CONFIG.C_PHYADDR 8 \
    CONFIG.RGMII_TXC_SKEW 0] $converter
# TX skew is provided by the PHY in this configuration. PHY address and delay
# settings must be verified/configured by firmware for the actual RTL8211 board.
foreach name {GMII_ETHERNET_1_0 MDIO_ETHERNET_1_0} {
    ris_pl_eth::remove_external_bus $name
}
ris_pl_eth::bus ps7/GMII_ETHERNET_1 gmii_to_rgmii_0/GMII
ris_pl_eth::bus ps7/MDIO_ETHERNET_1 gmii_to_rgmii_0/MDIO_GEM
ris_pl_eth::export_bus gmii_to_rgmii_0/RGMII pl_eth_rgmii
ris_pl_eth::export_bus gmii_to_rgmii_0/MDIO_PHY pl_eth_mdio

if {![llength [get_bd_cells -quiet reset_eth]]} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 reset_eth
}
ris_pl_eth::wire ps7/FCLK_CLK1 gmii_to_rgmii_0/clkin
ris_pl_eth::wire ps7/FCLK_CLK1 reset_eth/slowest_sync_clk
ris_pl_eth::wire ps7/FCLK_RESET1_N reset_eth/ext_reset_in
ris_pl_eth::wire constant_one/dout reset_eth/dcm_locked
ris_pl_eth::wire reset_eth/peripheral_reset gmii_to_rgmii_0/tx_reset
ris_pl_eth::wire reset_eth/peripheral_reset gmii_to_rgmii_0/rx_reset

# Optional PHY event input is inactive. Regular GEM RX/TX interrupts remain in PS.
set ext [get_bd_ports -quiet ENET1_EXT_INTIN_0]
if {[llength $ext]} {
    set net [get_bd_nets -quiet -of_objects $ext]
    if {[llength $net]} {delete_bd_objs $net}
    delete_bd_objs $ext
}
if {![llength [get_bd_cells -quiet constant_zero]]} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 constant_zero
}
set_property -dict [list CONFIG.CONST_WIDTH 1 CONFIG.CONST_VAL 0] [get_bd_cells constant_zero]
ris_pl_eth::wire constant_zero/dout ps7/ENET1_EXT_INTIN

# Dedicated PHY RESETB control: PS GPIO 54 = EMIO GPIO[0], independent of MIO47.
# GPIO output data resets to zero, holding RESETB asserted until firmware releases
# it after the required hold time. Loopback permits GPIO input-state inspection.
ris_pl_eth::wire ps7/GPIO_O ps7/GPIO_I
set p [get_bd_ports -quiet pl_eth_reset_n]
if {![llength $p]} {
    set p [create_bd_port -dir O -from 0 -to 0 pl_eth_reset_n]
    connect_bd_net [get_bd_pins ps7/GPIO_O] $p
}

validate_bd_design -force
if {[get_property CONFIG.PCW_ACT_FPGA0_PERIPHERAL_FREQMHZ $ps] != 100.0} {
    error "Original RIS FCLK0 must remain 100 MHz"
}
if {[get_property CONFIG.PCW_ACT_FPGA1_PERIPHERAL_FREQMHZ $ps] != 200.0} {
    error "Ethernet reference FCLK1 must be 200 MHz"
}
if {[get_property CONFIG.C_EXT_RESET_HIGH [get_bd_cells reset_eth]] != 0} {
    error "Ethernet reset must accept active-low FCLK_RESET1_N"
}
save_bd_design
puts RIS_PL_ETH_BD_CONFIGURED
