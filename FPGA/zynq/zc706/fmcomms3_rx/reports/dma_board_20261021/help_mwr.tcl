connect -url tcp:127.0.0.1:3121
targets -set -filter {name == "APU"}
puts [help mwr]
exit
