# Run in a separate Vivado batch process. The default invocation copies the
# project and sources to a temporary directory, regenerates the BD there and
# synthesizes the copy. Active project, GUI state and hardware stay untouched.
# Usage: vivado -mode batch -source scripts/verify_ad9361_rx_integration.tcl
#        -tclargs /tmp/ad9361_rx_integration [isolated_project_directory]
# Optional isolated_project_directory reuses a previously prepared copy.
# Never pass the active project directory as the optional argument.
set rx_project_root [file normalize [file join [file dirname [info script]] ..]]
if {[llength $argv] < 1 || [llength $argv] > 2} {error "Expected output directory and optional isolated project directory"}
set rx_validation_out [file normalize [lindex $argv 0]]
file mkdir $rx_validation_out
if {[llength $argv] == 1} {
    set rx_temp_root /tmp
    if {[info exists ::env(TMPDIR)]} {set rx_temp_root $::env(TMPDIR)}
    set rx_copy_root [file normalize [file join $rx_temp_root ad9361_rx_validation_[pid]_[clock seconds]]]
    # Python's copytree follows source symlinks into actual copies, ensuring
    # subsequent path rewriting cannot write through a link to source files.
    exec python3 -c {
from pathlib import Path
import shutil, sys
source, target = map(Path, sys.argv[1:])
target.mkdir(parents=True, exist_ok=False)
shutil.copy2(source / "PZ_UART.xpr", target / "PZ_UART.xpr")
shutil.copytree(source / "PZ_UART.srcs", target / "PZ_UART.srcs", symlinks=False)
extensions = (".xpr", ".xml", ".xci", ".bd", ".prj", ".tcl", ".v", ".sv", ".vh", ".vhd", ".xdc")
for path in target.rglob("*"):
    if path.is_file() and path.suffix in extensions:
        try:
            data = path.read_text()
        except UnicodeDecodeError:
            continue
        if str(source) in data:
            path.write_text(data.replace(str(source), str(target)))
    } $rx_project_root $rx_copy_root
} else {
    set rx_copy_root [file normalize [lindex $argv 1]]
}
if {$rx_copy_root eq $rx_project_root} {error "Refusing to regenerate the active project"}
set rx_manifest [open $rx_validation_out/project_snapshot.txt w]
puts $rx_manifest "SOURCE=$rx_project_root\nSNAPSHOT=$rx_copy_root"
close $rx_manifest
open_project $rx_copy_root/PZ_UART.xpr
set rx_bd [get_files */design_1.bd]
open_bd_design $rx_bd
update_module_reference [get_ips design_1_ad9361_rx_axis_0_0]
validate_bd_design
set_property synth_checkpoint_mode None $rx_bd
generate_target all $rx_bd
set_param general.maxThreads 8
# XPM_LIBRARIES is already configured in the saved project; do not mutate it.
synth_design -top pz7035_top -part xc7z035ffg900-2

# Vivado loads the project's synthesis constraints while synthesizing, then
# applies implementation constraints when opening the resulting netlist.
# Do not read the ILA XDC a second time: it would add extra probe objects.

set rx_hierarchy u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst
if {[llength [get_cells -quiet $rx_hierarchy/u_capture_fifo]] != 1} {
    error "Rewritten RX FIFO missing from the integrated design"
}
foreach {rx_signal rx_width} {debug_axis_data 64 debug_axis_flags 10 debug_sample_count 24 debug_clock_count 24 debug_raw_rx 49} {
    for {set rx_bit 0} {$rx_bit < $rx_width} {incr rx_bit} {
        set rx_net [format {%s/%s[%d]} $rx_hierarchy $rx_signal $rx_bit]
        if {[llength [get_nets -quiet $rx_net]] != 1} {error "Missing RX debug net: $rx_net"}
    }
}
if {[llength [get_debug_cores -quiet ila_ad9361_rx]] != 1} {
    error "Rewritten receiver ILA constraint was not loaded"
}
if {[llength [get_debug_ports -quiet ila_ad9361_rx/probe*]] != 5} {
    error "Receiver ILA must contain exactly five probes"
}
foreach {rx_probe rx_width} {probe0 64 probe1 10 probe2 24 probe3 24 probe4 49} {
    if {[get_property PORT_WIDTH [get_debug_ports ila_ad9361_rx/$rx_probe]] != $rx_width} {
        error "Incorrect receiver ILA width: $rx_probe"
    }
}
set rx_ila_clock [get_clocks -of_objects [get_pins $rx_hierarchy/m_axis_aclk]]
if {[llength $rx_ila_clock] != 1 || abs([get_property PERIOD $rx_ila_clock] - 10.0) > 0.001} {
    error "Expected the receiver AXIS/ILA domain to be 100 MHz"
}
report_utilization -hierarchical -file $rx_validation_out/utilization.rpt
report_cdc -details -file $rx_validation_out/cdc.rpt
report_drc -file $rx_validation_out/drc.rpt
report_timing_summary -file $rx_validation_out/timing_synthesis.rpt
write_xdc -force $rx_validation_out/validated_constraints.xdc
implement_debug_core
write_debug_probes -force $rx_validation_out/validated_rx_probes.ltx
set rx_probe_validation [exec python3 $rx_project_root/scripts/check_ad9361_rx_probes.py $rx_validation_out/validated_rx_probes.ltx]
puts $rx_probe_validation
set rx_probe_report [open $rx_validation_out/probe_validation.txt w]
puts $rx_probe_report $rx_probe_validation
close $rx_probe_report
write_checkpoint -force $rx_validation_out/pz7035_top_rewrite_synth.dcp
set rx_status_file [open $rx_validation_out/status.txt w]
puts $rx_status_file "PASS: full-project synthesis and rewritten ILA probe validation"
close $rx_status_file
puts "AD9361_REWRITE_INTEGRATION_PASS=$rx_validation_out"
close_project
