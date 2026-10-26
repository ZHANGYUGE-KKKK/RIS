connect -url tcp:127.0.0.1:3121
targets -set -nocase -filter {name =~ "*A9*#0"}
configparams force-mem-access 1
foreach address {0xF8000100 0xF8000104 0xF8000108 0xF800010C 0xF8000120 0xF8000170 0x80020000 0x80020008 0x82000000 0x82000040 0x82000044 0x82000054 0x82000058 0x82001008} {
    puts [format {READBACK %08x %08x} $address [mrd -value $address]]
}
puts [targets]
configparams force-mem-access 0
disconnect
exit
