# 
# Usage: To re-create this platform project launch xsct with below options.
# xsct /home/yyz/work/z035/vitis_code/z035_basic/platform.tcl
# 
# OR launch xsct and run below command.
# source /home/yyz/work/z035/vitis_code/z035_basic/platform.tcl
# 
# To create the platform in a different location, modify the -out option of "platform create" command.
# -out option specifies the output directory of the platform project.

platform create -name {z035_basic}\
-hw {/home/yyz/work/z035/design_1_wrapper.xsa}\
-proc {ps7_cortexa9_0} -os {standalone} -fsbl-target {psu_cortexa53_0} -out {/home/yyz/work/z035/vitis_code}

platform write
platform generate -domains 
platform active {z035_basic}
platform generate
platform active {z035_basic}
platform config -updatehw {/home/yyz/work/RIS/zynq/z035/design_1_wrapper.xsa}
platform generate -domains 
platform config -updatehw {/home/yyz/work/RIS/zynq/z035/design_1_wrapper.xsa}
platform generate -domains 
platform active {z035_basic}
platform config -updatehw {/home/yyz/work/RIS/zynq/z035/design_1_wrapper.xsa}
platform generate -domains 
platform config -updatehw {/home/yyz/work/RIS/zynq/z035/design_1_wrapper.xsa}
platform generate -domains 
platform active {z035_basic}
platform active {z035_basic}
