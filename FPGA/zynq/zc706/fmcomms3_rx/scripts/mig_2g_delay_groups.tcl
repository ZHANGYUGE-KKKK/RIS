# Leave AD9361's independent IDELAY group unchanged.
set unused_ctrl [get_cells -hier -filter {REF_NAME == IDELAYCTRL && NAME =~ *mig_7series_0*/u_idelayctrl_200}]
set data_delays [get_cells -hier -filter {NAME =~ *mig_7series_0* && REF_NAME =~ IDELAYE2*}]
if {[llength $unused_ctrl] != 1 || [llength $data_delays] != 64} {
    error "Unexpected 2GB MIG delay/controller count"
}
set group [get_property IODELAY_GROUP [lindex $data_delays 0]]
if {![string match *_IODELAY_MIG1 $group]} {error "Unexpected MIG 400MHz data delay group: $group"}
foreach d $data_delays {
    if {[get_property IODELAY_GROUP $d] ne $group} {error "MIG data delay groups differ"}
}
reset_property IODELAY_GROUP $unused_ctrl
puts "DDR2G delay groups: 64 MIG data delays retain $group; unused 200MHz readiness controller ungrouped"
