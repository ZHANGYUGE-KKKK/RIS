set root [file dirname [file normalize [info script]]]
set mode [lindex $argv 0]
set out [file join $root $mode]
file mkdir $out
create_project -in_memory -part xc7z045ffg900-2
read_verilog [file join $root ${mode}.v]
read_xdc [file join $root ${mode}.xdc]
if {[catch {
 synth_design -top clock_probe
 report_io -file [file join $out io.rpt]
 opt_design
 place_design
 route_design
 # Check every PACKAGE_PIN constraint against the routed design.
 set xf [open [file join $root ${mode}.xdc] r]
 set xt [read $xf]
 close $xf
 set pf [open [file join $out pin_verification.txt] w]
 set checked 0
 foreach line [split $xt "\n"] {
  if {[regexp {^set_property PACKAGE_PIN (\S+) \[get_ports (\S+)\]} $line unused expected port]} {
   set actual [get_property PACKAGE_PIN [get_ports $port]]
   puts $pf "$port expected=$expected actual=$actual"
   if {$actual ne $expected} {close $pf; error "Pin mismatch: $port expected $expected actual $actual"}
   incr checked
  }
 }
 puts $pf "PASS: $checked package pin constraints match routed design"
 close $pf
 report_io -file [file join $out routed_io.rpt]
 report_route_status -file [file join $out route_status.rpt]
 report_drc -file [file join $out drc.rpt]
 report_utilization -file [file join $out utilization.rpt]
 report_timing_summary -file [file join $out timing_summary.rpt]
 report_clock_networks -file [file join $out clock_networks.rpt]
 write_checkpoint -force [file join $out routed.dcp]
 write_bitstream -force [file join $out clock_probe.bit]
} reason]} {
 set f [open [file join $out result.txt] w]; puts $f "FAIL: $reason"; close $f
 exit 1
}
set f [open [file join $out result.txt] w]; puts $f "PASS: synthesis, placement, routing and bitstream generation"; close $f
exit 0
