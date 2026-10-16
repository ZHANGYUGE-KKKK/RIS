> 已完成硬件构建及上板调试，最新结果见 [上板报告](../reference_alignment_board/README.md)。以下为构建前的修改记录。

# 参考工程输入延时与双沿配对对齐

当前源设计已设置：D0..D5与FRAME七路IDELAY均12 taps（35位参数0x318C6318C），FALLING_EDGE_DELAY=1。上升沿数据不额外延迟，下降沿数据和FRAME一起寄存一拍后配对，与参考axi_ad9361_dev_if_idelay.v一致。

修改位置：rfmc6000_iq_axis.v默认参数、design_1.bd实例参数及scripts/build_fmcomms3.tcl。通过Vivado GUI更新module reference、validate_bd_design并保存；见bd_update.txt。测试平台同步12 taps，使用UNISIM IDDR/IDELAY及原参考解码器检查。

尚未重新生成output products/综合/布局布线/bit/XSA，也未下载本次硬件修改。当前开发板及已有bit/XSA仍为8 taps、FALLING_EDGE_DELAY=0，软件为61.44MSPS参考最终配置。

仿真结果：现有6组UNISIM/XPM测试全部通过。参考组合（12taps/FALL_DELAY1）逐元组与原参考解码器一致；另覆盖沿选择、4096样本长包、lane延时偏差、替代配对模式、背压、overflow、FRAME错误及跨域诊断。详见simulation.log及各case的run.log。
