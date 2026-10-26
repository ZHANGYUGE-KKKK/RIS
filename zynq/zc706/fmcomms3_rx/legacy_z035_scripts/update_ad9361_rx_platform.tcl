# Update the existing Vitis 2020.2 platform from the exported XSA.
# Usage: xsct scripts/update_ad9361_rx_platform.tcl
set board_root [file normalize [file join [file dirname [info script]] ..]]
set workspace $board_root/vitis_code
setws $workspace
platform read $workspace/key_ctrl/platform.spr
platform active key_ctrl
platform config -updatehw $board_root/pz7035_top.xsa
platform generate -quick
platform generate -domains standalone_domain
puts "AD9361_RX_VITIS_PLATFORM_PASS"
exit
