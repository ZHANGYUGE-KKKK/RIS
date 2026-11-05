# User-defined slices of existing ILA ports; no RTL/BIT/XSA change.
# Reapply after refresh_hw_device, which reloads the original LTX probe list.
set iq_view_core [get_hw_ilas -filter {CELL_NAME == ila_rx_prefifo}]
if {[llength $iq_view_core] != 1} {error "Expected one pre-FIFO ILA"}
foreach {iq_view_name iq_view_range} {RX1_I 11:0 RX1_Q 23:12 RX2_I 35:24 RX2_Q 47:36} {
    set iq_view_probe [get_hw_probes -quiet -of_objects $iq_view_core -filter "NAME == $iq_view_name"]
    if {[llength $iq_view_probe] == 0} {
        set iq_view_probe [create_hw_probe -map "probe12\[$iq_view_range\]" "${iq_view_name}\[11:0\]" $iq_view_core]
    }
    set_property DISPLAY_RADIX SIGNED $iq_view_probe
    set_property DISPLAY_AS_ENUM false $iq_view_probe
}
foreach {iq_view_name iq_view_port} {RECORD_VALID probe27 REFERENCE_IQ_VALID probe13} {
    if {[llength [get_hw_probes -quiet -of_objects $iq_view_core -filter "NAME == $iq_view_name"]] == 0} {
        create_hw_probe -map $iq_view_port $iq_view_name $iq_view_core
    }
}
puts RX_IQ_VIEW_CONFIGURED
