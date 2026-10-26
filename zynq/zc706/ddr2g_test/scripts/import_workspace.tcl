# Register existing projects in the Eclipse workspace, without rebuilding them.
# Run while this test workspace is closed in the GUI.
set root [file normalize [file join [file dirname [info script]] ..]]
setws $root/vitis_workspace
foreach name {ddr2g_platform ddr2g_test ddr2g_test_system} {
    if {[catch {importprojects $root/vitis_workspace/$name} message]} {
        if {![string match -nocase {*already exists*} $message]} {error $message}
        puts "ALREADY_REGISTERED $name"
    } else {puts "IMPORTED $name"}
}
puts "APPLICATIONS: [app list]"
puts "PLATFORMS: [platform list]"
puts DDR2G_WORKSPACE_IMPORTED
exit
