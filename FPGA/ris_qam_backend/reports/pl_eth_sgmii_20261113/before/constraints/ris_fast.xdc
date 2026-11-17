# High-speed profile only. SHCP has 5 ns HIGH/LOW pulses at 100 MHz.
set_property SLEW FAST [get_ports {ris_data[*] ris_shcp[*] ris_stcp[*]}]
# Related 300 MHz MMCM clock is derived automatically. ODDR -> pad budget;
# this does not claim board-level setup/hold closure or measured RIS settling.
set fast_clock [get_clocks -of_objects [get_pins -hier -filter {REF_PIN_NAME == CLKOUT0 && NAME =~ *u_mmcm*}]]
# Start at the final ODDR launch clock pins: constrain C->Q->pad, rather than
# also treating asynchronous reset->Q propagation as a periodic data launch.
# Reset recovery/removal at the ODDR R pins remains fully timed.
set fast_oddr [get_cells -hier -filter {REF_NAME == ODDR && NAME =~ *fast_io*}]
set fast_launch [get_pins -of_objects $fast_oddr -filter {REF_PIN_NAME == C}]
set_max_delay 3.000 -datapath_only -from $fast_launch -to [get_ports {ris_data[*] ris_shcp[*] ris_stcp[*]}]
