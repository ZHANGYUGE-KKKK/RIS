# Companion to rfmc6000_iq_axis.v; add only when integrating that module.
# Recommended: set_property SCOPED_TO_REF rfmc6000_iq_axis [get_files ...]
# Only the asynchronous input to each synchronizer is excluded. Later stages
# remain timed/placed normally, aided by ASYNC_REG in the RTL.
# XPM owns its FIFO Gray-pointer/reset/BRAM timing constraints.
set_false_path -to [get_pins -quiet -hier -regexp {.*(ready_pipe_reg|arm_pipe_reg)\[0\]/D}]
set_false_path -to [get_pins -quiet -hier -regexp {.*g_status_cdc.*sync_pipe_reg\[0\]/D}]
