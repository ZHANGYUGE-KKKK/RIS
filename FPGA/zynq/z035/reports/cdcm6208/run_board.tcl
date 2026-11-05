set board_dir /home/yyz/work/RIS/zynq/z035
if {[llength [targets -target-properties -filter {name == "xc7z035"}]] != 1} {error "Expected one xc7z035"}
if {[llength [targets -target-properties -filter {name == "ARM Cortex-A9 MPCore #0"}]] != 1} {error "Expected one Cortex-A9 core 0"}
targets -set -filter {name == "ARM Cortex-A9 MPCore #0"}
catch {stop}
rst -system
after 1000
targets -set -filter {name == "xc7z035"}
fpga -file $board_dir/vitis_code/key_ctrlll/_ide/bitstream/pz7035_top.bit
targets -set -filter {name == "ARM Cortex-A9 MPCore #0"}
source $board_dir/vitis_code/key_ctrlll/_ide/psinit/ps7_init.tcl
ps7_init
ps7_post_config
dow $board_dir/vitis_code/key_ctrlll/Debug/key_ctrlll.elf
con
puts "CDCM_TEST_STARTED"
