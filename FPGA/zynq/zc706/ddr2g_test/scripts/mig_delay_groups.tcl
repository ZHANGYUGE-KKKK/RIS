# MIG 4.2 retains a 200MHz readiness controller even when all data delay
# elements use its separate 400MHz group. Keep the controller and its RDY
# connection, but remove the empty group so it can occupy a spare bank.
set unused_ctrl [get_cells -hier -filter {REF_NAME == IDELAYCTRL && NAME =~ */u_idelayctrl_200}]
if {[llength $unused_ctrl] != 1} {error "Expected one MIG 200MHz readiness controller"}
set data_delays [get_cells -hier -filter {REF_NAME =~ IDELAYE2*}]
if {[llength $data_delays] != 64} {error "Expected 64 MIG data delay elements"}
foreach d $data_delays {
    if {[get_property IODELAY_GROUP $d] ne "DDR_TEST_MIG_0_IODELAY_MIG1"} {
        error "Unexpected data delay group on $d; do not detach a controller in use"
    }
}
reset_property IODELAY_GROUP $unused_ctrl
puts "MIG delay groups checked: 64 data delays retain 400MHz calibration; unused 200MHz group detached"
