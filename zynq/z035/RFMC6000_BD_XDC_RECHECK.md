# RFMC6000 BD / XDC 复查

后续更新：用户已生成最新 wrapper，pz7035_top 已补齐六个输入端口（共16位）
及同名例化连接，第1项的顶层缺失问题已修复。与最新 wrapper 的78个端口
方向/位宽核对通过，Vivado RTL接口展开及全部16个ADC IO约束匹配通过，无
No ports matched；记录在 `reports/pz7035_top_adc_check.log`。
以下结论保留为首次复查时的设计状态。

2026-10-13，按当前磁盘保存的设计检查。结论：BD 结构验证通过；当前仍需更新
wrapper/手写顶层、将状态补零常量改为 0，并设置 CDC 文件的模块作用域。
本次仅审查和保存报告，原 BD/XPR 的 SHA256 与检查前一致。

## 已通过

- Vivado 2020.2 在 BD 副本执行 validate_bd_design，通过，无 BD Critical Warning。
- 采集模块 → AXIS FIFO → DMA S2MM，以及 DMA SG/S2MM → MIG 的接口连接正确。
- SG 和 S2MM 均已映射 0x40000000–0x7FFFFFFF；PS 与两路 DMA 访问同一 MIG。
- 控制寄存器地址保持：RIS GPIO 0x80010000、采集 GPIO 0x80020000、DMA 0x81000000。
- DMA 仅 S2MM，SG 开启，Stream/Memory 写口均 64 位，长度字段已改为 23 位。
- FIFO 64 位、TKEEP/TLAST 开启，同步时钟，普通 FIFO 模式。
- 采集 GPIO 通道1为1位输出直接接 ARM；通道2为32位全输入。
- 状态位 bit0..5 依次为 ready、frame_locked、active、overflow、frame_error、delay_error。
- Concat 有7个输入，低6路每路1位，高一路26位；宽度正确。
- PS 100 MHz、MIG 200 MHz、DMA/采集/FIFO 时钟复位、DMA 中断连接正确。
- 按用户要求保留系统复位，不增加 GPIO 采集复位。
- XPM_CDC/XPM_FIFO/XPM_MEMORY 已启用。
- 两份 ADC XDC 已加入工程，启用 synthesis/implementation。
- ADC 的16个LOC与现有34个手写LOC、71个MIG DDR3 LOC无冲突。
- IO模板在包含接收模块的独立顶层中匹配全部16个输入，均为 LVDS_25。
- CDC模板匹配2个控制同步器和7个状态同步器第一级；使用模块作用域后，
  独立综合网表 CDC 只有11条 CDC-3 Info，无 Warning/Critical。

## 1. 当前顶层尚未引出 ADC 输入

当前 design_1_wrapper.v 和 pz7035_top.v 仍没有以下端口：

```verilog
input wire rx_clk_p, rx_clk_n;
input wire rx_frame_p, rx_frame_n;
input wire [5:0] rx_data_p, rx_data_n;
```

BD 的 Make External 已完成，但输入还没有穿过这两层。实际工程顶层是
pz7035_top。基于当前顶层和现有 wrapper 接口的 RTL 展开检查确认：16个ADC
输入全部缺失，IO XDC 的17次端口查询（含采样时钟）均出现 No ports matched。
因此当前 ADC IO 约束尚未实际约束到板级端口，不能从子板接收采样数据。

处理：在原工程生成最新 HDL wrapper，再在手写 pz7035_top 添加上述端口，
例化中同名连接。模块内部已有 IBUFDS/BUFG，外部不增加输入缓冲。

## 2. 补高位常量为1，需要改为0

xlconstant_9361_status 的 CONST_WIDTH=26，但 CONST_VAL 仍为默认1。
输出是26'd1，拼接到GPIO高26位后，状态字 bit6 恒为1，bit31:7 为0；
低六个状态位的连接顺序是正确的。

处理：双击该 Constant，将 Const Val 设置为0。

```tcl
set_property CONFIG.CONST_VAL 0 [get_bd_cells xlconstant_9361_status]
```

## 3. CDC文件作用域尚未设置

rfmc6000_iq_axis_cdc.xdc 当前 SCOPED_TO_REF 为空。其正则在独立网表中能匹配，
当前写法没有发现语法错误；建议限定到接收模块，避免以后匹配其他模块同名寄存器。

```tcl
set_property SCOPED_TO_REF rfmc6000_iq_axis \
    [get_files *rfmc6000_iq_axis_cdc.xdc]
```

rfmc6000_iq_axis_io.xdc 保持不设置作用域，因为其 PACKAGE_PIN/create_clock
针对 pz7035_top 的外部端口。

## 其他边界

- 外部 AXIS FIFO 仍为512 beat / 4 KiB，没有扩到前次建议的16384 beat。
  这不是连接错误，但可吸收的停顿很短；内部另有4096 beat / 32 KiB。
- IO XDC 尚未包含源同步DDR set_input_delay（上升/下降沿、min/max）。目前
  原始 DATA_CLK 为4.069 ns。需要结合实际 AD9361 接口延迟设置和PCB偏斜补齐
  输入时序，并用PN测试码确认采样窗口，不能把内部时序通过视为板级采样已验证。
- 本次没有运行整机综合/实现或上板DMA记录：当前顶层输入缺失，需要先修正。
  CDC/IO网表检查采用接收模块的独立层次化顶层，当前板级端口缺失检查只展开
  现有顶层与wrapper接口；它们不能替代修正后整机的 DRC、STA 和 report_cdc。

完整检查记录：`reports/rfmc6000_bd_xdc_recheck/`。
