# Run in a fresh XSCT process after platform generation.
set root [file normalize [file join [file dirname [info script]] ..]]
setws $root/vitis_code
if {![file exists $root/vitis_code/key_ctrlll/key_ctrlll.prj]} {
    app create -name key_ctrlll -platform key_ctrl -domain standalone_domain -template {Empty Application}
    importsources -name key_ctrlll -path $root/software/src -linker-script
}
app config -name key_ctrlll build-config Debug
app build -name key_ctrlll
puts ZC706_VITIS_APPLICATION_PASS
exit
