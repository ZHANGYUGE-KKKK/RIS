connect -url tcp:127.0.0.1:3121
puts [targets]
targets -set -nocase -filter {name =~ "*A9*#0"}
configparams force-mem-access 1
foreach a {0x82000000 0x82000040 0x82000044 0x82000054 0x82000058 0x8200005c 0x82001000 0x82001004 0x82001008 0x80020000 0x80020008 0x81000030 0x81000034} {
    puts [format {REGISTER %08x %08x} $a [mrd -value $a]]
}
puts "RADIO [mrd -value 0x00148030 12]"
puts "CAPTURE [mrd -value 0x001480b4 6]"
puts "RF_CONFIG [mrd -value 0x00148860 2]"
puts "OFFICIAL_REPORT [mrd -value 0x00148ed8 12]"
puts [help con]
puts [help rrd]
configparams force-mem-access 0
disconnect
exit
