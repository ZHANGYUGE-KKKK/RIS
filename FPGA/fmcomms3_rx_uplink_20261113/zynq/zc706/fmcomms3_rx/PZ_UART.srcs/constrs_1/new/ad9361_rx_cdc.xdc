# Companion to the rewritten ad9361_rx_axis (scoped to this reference).
# Reset, one-bit status/ARM, counters and the async FIFO use XPM primitives.
# Their generated XDC constrains the first synchronizer stages and Gray buses.
# ADI register/control transfers use the separately loaded vendor XDC files.
# No clock-group false paths: later synchronizer stages and unrelated paths
# remain timed. No names from the removed local frontend are constrained here.
