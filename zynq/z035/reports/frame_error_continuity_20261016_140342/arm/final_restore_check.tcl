connect -url tcp:127.0.0.1:3121
targets -set -nocase -filter {name =~ "*A9*#0"}
configparams force-mem-access 1
# FCLK0 reset also reset RIS GPIO. Its software object was not changed by
# the diagnostic; restore its saved command and output direction.
set command [mrd -value 0x001480a8]
puts [format {RESTORE_RIS_SOFTWARE_COMMAND=%08x} $command]
mwr 0x80010004 0
mwr 0x80010000 $command
foreach a {0x80010004 0x80020000 0x80020004 0x80020008 0x8002000c 0x81000030 0x81000034 0x82000040 0x82000044 0x82001008} {
    puts [format {FINAL_REGISTER %08x %08x} $a [mrd -value $a]]
}
puts [targets]
configparams force-mem-access 0
disconnect
exit
