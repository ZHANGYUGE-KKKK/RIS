# Use a fresh XSCT process after platform generation so the Eclipse platform
# catalog cannot retain a transient, incomplete export directory.
set board_root [file normalize [file join [file dirname [info script]] ..]]
setws $board_root/vitis_code
puts "RX_APPLICATION_BUILD_CONFIG=[app config -name key_ctrlll build-config]"
app build -name key_ctrlll
set elf $board_root/vitis_code/key_ctrlll/Debug/key_ctrlll.elf
if {![file exists $elf]} {error "Application ELF missing after build"}
puts "AD9361_RX_VITIS_BUILD_PASS ELF=$elf MTIME=[file mtime $elf]"
exit
