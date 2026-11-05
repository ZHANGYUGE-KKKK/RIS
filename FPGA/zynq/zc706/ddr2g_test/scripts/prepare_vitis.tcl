# Create an isolated workspace; never touches the open RX Vitis workspace.
set root [file normalize [file join [file dirname [info script]] ..]]
set hardware $root/export/ddr2g_test.xsa
if {![file exists $hardware]} {set hardware $root/reports/ddr2g_bsp.xsa}
setws $root/vitis_workspace
if {![file exists $root/vitis_workspace/ddr2g_platform/platform.spr]} {
    platform create -name ddr2g_platform -hw $hardware -proc ps7_cortexa9_0 -os standalone -out $root/vitis_workspace
} else {
    platform active ddr2g_platform
    platform config -updatehw $hardware
}
platform write
platform generate
if {![file exists $root/vitis_workspace/ddr2g_test/.project]} {
    app create -name ddr2g_test -platform ddr2g_platform -domain standalone_domain -template {Empty Application}
    importsources -name ddr2g_test -path $root/software
}
app build -name ddr2g_test
# Platform generation does not register its Eclipse project in the GUI index.
# Import the existing project descriptors as well as creating the SCW platform.
foreach name {ddr2g_platform ddr2g_test ddr2g_test_system} {
    importprojects $root/vitis_workspace/$name
}
puts DDR2G_VITIS_READY
exit
