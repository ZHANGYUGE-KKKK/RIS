# Metadata-only handoff for parallel software compilation; final XSA includes BIT.
set root [file normalize [file join [file dirname [info script]] ..]]
open_project $root/vivado/ddr2g_test.xpr
write_hw_platform -fixed -force -file $root/reports/ddr2g_bsp.xsa
close_project
exit
