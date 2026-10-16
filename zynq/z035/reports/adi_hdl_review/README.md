# ADI HDL / FMCOMMS3 接收链路核对

用户目标：查看 https://github.com/analogdevicesinc/hdl ，对照当前 PZ7035 + FMCOMMS3 工程的接收/FRAME/CDC 排查。

本轮仅核对源代码和文档，源码快照位于 main/ 和 2021_r1/。
main 固定提交：4b12bb58a17edb4c67f63eb367b42d3d3a4e5c91。

## 工程入口和接收链路

FMCOMMS2/3/4 共用 projects/fmcomms2；Zynq-7000 可参考 zc706 载板目录。
官方 ZC706 项目需要适配当前 PZ7035 引脚、PS配置与MIG，不能直接烧录。

主线 fmcomms2_bd.tcl 的接收链为：
AD9361 DATA/FRAME + DATA_CLK -> axi_ad9361 -> util_wfifo -> util_cpack2 -> axi_dmac -> DDR。
axi_ad9361 直接提供4路16位 adc_data_i0/q0/i1/q1、各路enable/valid；这些是经过可配置格式化/滤波/IQ校正的输出，选择原始采样时需配置旁路和数据格式。
ADC DMA 在该BD中使用FIFO写接口（DMA_TYPE_SRC=2），不是当前Xilinx AXI DMA的AXIS接口。
不能将官方ADC DMA连接直接套用到当前AXI DMA；可保留当前AXIS适配、异步FIFO、AXI DMA及MIG，移植前端并适配控制/软件。

接口l_clk来自AD9361接收时钟；2R2T按4分频、1R1T按2分频生成较低速采样域，util_wfifo承担相应跨域。
200MHz delay_clk用于输入延时校准，CPU/AXI控制时钟是另一用途，不能替代物理采样时钟。

## 与当前RTL最相关的差异

- 官方 library/xilinx/common/ad_data_in.v 在7系列使用IDELAYE2 + IDDR，IDDR_CLK_EDGE默认SAME_EDGE。
- 当前模块使用SAME_EDGE_PIPELINED，并配置FALLING_EDGE_DELAY=1。两者的流水级/沿关系不同，不能只改一个延迟参数就宣称等价。
- 官方在axi_ad9361_lvds_if.v中把两个IDDR输出统一按l_clk寄存，然后依据当前/上一拍FRAME组合拼接；没有照搬当前的“只对下降沿额外打一拍”链路。
- 官方延时值由AXI控制寄存器加载/读回，不能把固定12 taps理解为官方统一正确值。
- axi_ad9361_rx_pnmon对数据序列做检查；PN_ERR/PN_OOS可由软件读出。仅FRAME合法/adc_status为高不能证明IQ无误。延时扫描需要配合软件和9361测试序列。
- 官方文档明确2R2T LVDS DDR为8个边沿/4个时钟周期，FRAME位序11110000。当前64拍记录中未额外延迟FRAME对00/11各持续6个RX周期，与预期各2周期仍不一致；不能仅因替换官方前端就预先断言根因消除。

## 工具版本

下载的main/scripts/adi_env.tcl明确要求Vivado 2025.1；2021_r1/projects/scripts/adi_project_xilinx.tcl和library/scripts/adi_ip_xilinx.tcl明确要求2021.1。
当前安装使用2020.2。因此不能把上述版本称为2020.2官方匹配版，也不能仅绕过版本检查就认为完成适配。
后续需选择固定版本并评估/处理向2020.2的移植，或另行确定工具版本升级；本轮没有构建验证。

额外审查：2021_r1版本的rx_error_r1/r2把2位rx_frame_s与4位常量比较，其中1100/1111比较分支不可能为真；这是从源码可直接观察到的宽度问题，其具体影响需专项验证，不建议不加检查地整体照抄该历史标签。

## 建议

优先建立官方接收前端+PN监测的对照，配置绕过滤波/校正以保留原始IQ。
保留当前板级接口和DMA/MIG结构，补上官方前端的AXI-Lite寄存器支持、9361测试序列和软件延时扫描，再用PN通过与数据连续性作为验收。
这是评估建议，本轮没有改动当前RTL、BD、XDC、驱动，也未重构建/下载硬件。

## 官方来源

- https://analogdevicesinc.github.io/hdl/projects/fmcomms2/index.html
- https://analogdevicesinc.github.io/hdl/library/axi_ad9361/index.html
- https://github.com/analogdevicesinc/hdl/blob/main/library/axi_ad9361/xilinx/axi_ad9361_lvds_if.v
- https://github.com/analogdevicesinc/hdl/blob/main/library/xilinx/common/ad_data_in.v
- https://github.com/analogdevicesinc/hdl/blob/main/library/axi_ad9361/axi_ad9361_rx_pnmon.v
- https://github.com/analogdevicesinc/hdl/blob/main/projects/fmcomms2/common/fmcomms2_bd.tcl
- https://github.com/analogdevicesinc/hdl/blob/main/scripts/adi_env.tcl
- https://github.com/analogdevicesinc/hdl/blob/2021_r1/projects/scripts/adi_project_xilinx.tcl
