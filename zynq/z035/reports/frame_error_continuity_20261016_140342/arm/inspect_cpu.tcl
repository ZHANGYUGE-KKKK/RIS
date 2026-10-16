connect -url tcp:127.0.0.1:3121
targets -set -nocase -filter {name =~ "*A9*#0"}
stop
puts [rrd]
puts "PC=[rrd pc]"
puts "SP=[rrd sp]"
puts "CPSR=[rrd cpsr]"
puts "MAIN_OPCODES [mrd -value 0x00120508 4]"
puts [help bpadd]
con
disconnect
exit
