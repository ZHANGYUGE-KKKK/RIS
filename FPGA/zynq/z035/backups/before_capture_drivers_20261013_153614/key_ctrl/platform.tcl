# 
# Usage: To re-create this platform project launch xsct with below options.
# xsct /home/yyz/work/RIS/zynq/z035/vitis_code/key_ctrl/platform.tcl
# 
# OR launch xsct and run below command.
# source /home/yyz/work/RIS/zynq/z035/vitis_code/key_ctrl/platform.tcl
# 
# To create the platform in a different location, modify the -out option of "platform create" command.
# -out option specifies the output directory of the platform project.

platform create -name {key_ctrl}\
-hw {/home/yyz/work/RIS/zynq/z035/pz7035_top.xsa}\
-proc {ps7_cortexa9_0} -os {standalone} -fsbl-target {psu_cortexa53_0} -out {/home/yyz/work/RIS/zynq/z035/vitis_code}

platform write
platform generate -domains 
platform active {key_ctrl}
platform generate
platform config -updatehw {/home/yyz/work/RIS/zynq/z035/pz7035_top.xsa}
platform generate
platform generate -domains standalone_domain,zynq_fsbl 
platform active {key_ctrl}
platform config -updatehw {/home/yyz/work/RIS/zynq/z035/pz7035_top.xsa}
