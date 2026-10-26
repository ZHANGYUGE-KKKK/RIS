# Read-only enumeration. Does not stop/reset/program any target.
set url tcp:127.0.0.1:3121
if {[info exists ::env(RIS_HW_SERVER)]} {set url $::env(RIS_HW_SERVER)}
connect -url $url
puts [targets]
puts [jtag targets]
puts [targets -target-properties]
disconnect
exit
