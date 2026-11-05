# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "FALLING_EDGE_DELAY" -parent ${Page_0}
  ipgui::add_param $IPINST -name "FIFO_DEPTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "INPUT_DELAY_TAPS" -parent ${Page_0}
  ipgui::add_param $IPINST -name "IO_DELAY_GROUP" -parent ${Page_0}
  ipgui::add_param $IPINST -name "I_ON_FALLING_EDGE" -parent ${Page_0}
  ipgui::add_param $IPINST -name "PACKET_SAMPLES" -parent ${Page_0}


}

proc update_PARAM_VALUE.FALLING_EDGE_DELAY { PARAM_VALUE.FALLING_EDGE_DELAY } {
	# Procedure called to update FALLING_EDGE_DELAY when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.FALLING_EDGE_DELAY { PARAM_VALUE.FALLING_EDGE_DELAY } {
	# Procedure called to validate FALLING_EDGE_DELAY
	return true
}

proc update_PARAM_VALUE.FIFO_DEPTH { PARAM_VALUE.FIFO_DEPTH } {
	# Procedure called to update FIFO_DEPTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.FIFO_DEPTH { PARAM_VALUE.FIFO_DEPTH } {
	# Procedure called to validate FIFO_DEPTH
	return true
}

proc update_PARAM_VALUE.INPUT_DELAY_TAPS { PARAM_VALUE.INPUT_DELAY_TAPS } {
	# Procedure called to update INPUT_DELAY_TAPS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.INPUT_DELAY_TAPS { PARAM_VALUE.INPUT_DELAY_TAPS } {
	# Procedure called to validate INPUT_DELAY_TAPS
	return true
}

proc update_PARAM_VALUE.IO_DELAY_GROUP { PARAM_VALUE.IO_DELAY_GROUP } {
	# Procedure called to update IO_DELAY_GROUP when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.IO_DELAY_GROUP { PARAM_VALUE.IO_DELAY_GROUP } {
	# Procedure called to validate IO_DELAY_GROUP
	return true
}

proc update_PARAM_VALUE.I_ON_FALLING_EDGE { PARAM_VALUE.I_ON_FALLING_EDGE } {
	# Procedure called to update I_ON_FALLING_EDGE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.I_ON_FALLING_EDGE { PARAM_VALUE.I_ON_FALLING_EDGE } {
	# Procedure called to validate I_ON_FALLING_EDGE
	return true
}

proc update_PARAM_VALUE.PACKET_SAMPLES { PARAM_VALUE.PACKET_SAMPLES } {
	# Procedure called to update PACKET_SAMPLES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.PACKET_SAMPLES { PARAM_VALUE.PACKET_SAMPLES } {
	# Procedure called to validate PACKET_SAMPLES
	return true
}


proc update_MODELPARAM_VALUE.FIFO_DEPTH { MODELPARAM_VALUE.FIFO_DEPTH PARAM_VALUE.FIFO_DEPTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.FIFO_DEPTH}] ${MODELPARAM_VALUE.FIFO_DEPTH}
}

proc update_MODELPARAM_VALUE.PACKET_SAMPLES { MODELPARAM_VALUE.PACKET_SAMPLES PARAM_VALUE.PACKET_SAMPLES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.PACKET_SAMPLES}] ${MODELPARAM_VALUE.PACKET_SAMPLES}
}

proc update_MODELPARAM_VALUE.INPUT_DELAY_TAPS { MODELPARAM_VALUE.INPUT_DELAY_TAPS PARAM_VALUE.INPUT_DELAY_TAPS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.INPUT_DELAY_TAPS}] ${MODELPARAM_VALUE.INPUT_DELAY_TAPS}
}

proc update_MODELPARAM_VALUE.I_ON_FALLING_EDGE { MODELPARAM_VALUE.I_ON_FALLING_EDGE PARAM_VALUE.I_ON_FALLING_EDGE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.I_ON_FALLING_EDGE}] ${MODELPARAM_VALUE.I_ON_FALLING_EDGE}
}

proc update_MODELPARAM_VALUE.FALLING_EDGE_DELAY { MODELPARAM_VALUE.FALLING_EDGE_DELAY PARAM_VALUE.FALLING_EDGE_DELAY } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.FALLING_EDGE_DELAY}] ${MODELPARAM_VALUE.FALLING_EDGE_DELAY}
}

proc update_MODELPARAM_VALUE.IO_DELAY_GROUP { MODELPARAM_VALUE.IO_DELAY_GROUP PARAM_VALUE.IO_DELAY_GROUP } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.IO_DELAY_GROUP}] ${MODELPARAM_VALUE.IO_DELAY_GROUP}
}

