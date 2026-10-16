# 2026-10-13 整机时序修复

工程：`PZ_UART.xpr`，顶层 `pz7035_top`，器件 `xc7z035ffg900-2`，Vivado 2020.2。

## 原始失败路径

实际整机布线报告中有 5 条 setup/recovery 失败路径，hold 全部通过：

| 路径 | 数量 | 最差 slack | 原因 |
| --- | ---: | ---: | --- |
| PS FCLK0 复位输出 → `rx_reset_pipe_reg[0:2]/CLR` | 3 | -2.016 ns | 异步复位同步链的 CLR 恢复/移除检查缺少例外；100 MHz 与外部 RX 时钟被按相关时钟分析，出现 0.005 ns 边沿要求 |
| `rx_reset_pipe_reg[2]` → lane 3、6 的 IDDR/R | 2 | -0.012 / -0.006 ns | RX 时钟内高扇出复位到 IDDR 下降沿的半周期恢复路径，要求约 2.034 ns |

IQ 数据路径没有 setup/hold 失败。

## 修改

- `rfmc6000_iq_axis_cdc.xdc`：只对 `rx_reset_pipe`、`axis_reset_pipe`、
  `ref_reset_pipe` 三个三级复位同步链直接接收 `aresetn` 的 CLR 引脚设置
  `set_false_path`。复位同步链级间路径和其输出到后级逻辑仍正常计时。
- `rfmc6000_iq_axis.v`：7 路 IDDR 的 R/S 固定为 0，与 RFMC6000 7035 参考工程
  相同，持续接收 DATA/FRAME。后级对齐寄存器、组帧状态和 FIFO 仍正常复位；
  三级同步释放、启动等待和完整 FRAME 获取过程会在接纳新样本前刷新流水线。
- CDC 文件在实际工程中设置 `SCOPED_TO_REF=rfmc6000_iq_axis`，保留现有 XPM
  FIFO 的 Gray 指针最大延迟、总线偏斜及复位约束。
- BD 刷新了模块引用。逐项比较确认 net 端点、AXI 接口和地址映射不变；接收端
  仍由现有系统 `aresetn` 复位，采集 GPIO 通道 1 仍只有 ARM bit0。

PS/AXIS 100 MHz、IDELAY 参考 200 MHz、RX 245.76 MHz 时序要求、IQ 格式和 DMA
配置均未改变，没有放宽时钟周期，也没有对整个 RX 时钟域设置 false path。

## 整机布线结果

| 指标 | 修复前 | 修复后 |
| --- | ---: | ---: |
| WNS | -2.016 ns | +0.183 ns |
| TNS | -6.065 ns | 0.000 ns |
| setup/recovery 失败端点 | 5 | 0 |
| WHS | +0.050 ns | +0.052 ns |
| hold 失败端点 | 0 | 0 |
| WPWS | +0.062 ns | +0.062 ns |
| 脉宽失败端点 | 0 | 0 |

正式报告：`reports/rfmc6000_timing_fix/timing_route.rpt`。

对实际 routed 网表核对：复位例外命中 9 个 CLR 引脚，原有数据同步例外命中
9 个第一级 D 引脚；7 路 IDDR/R 均连接到 GROUND。结果见
`reports/rfmc6000_timing_fix/signoff_details.log` 和 `exceptions_coverage.rpt`。

32 组 bus skew 约束全部通过，最差余量 +3.253 ns，包含接收 XPM FIFO 和 AXI
时钟转换 FIFO。CDC 没有 Critical 结果；2 条 CDC-8 Warning 均位于 MIG 自带
`u_iodelay_ctrl` 复位逻辑，接收模块手写同步链均识别为带 ASYNC_REG 的同步器。
DRC 没有 Error，保留 MIG 时钟缓冲/无负载网等既有 Warning 和 BRAM Advisory。
没有降级任何 DRC 检查。

## 功能验证与产物

`tests/run_rfmc6000_iq_axis.sh` 四组仿真全部通过，包括参考 RTL 的逐组 IQ 比较、
随机背压、TLAST、溢出停止、FRAME 故障、停止 RX 时钟后复位重启及旧数据清除、
停止参考时钟后的失锁处理。日志在 `reports/rfmc6000_timing_fix/iq_axis_*.run.log`。

整机综合、布局布线和 write_bitstream 均完成。产物位于：

- `PZ_UART.runs/impl_1/pz7035_top.bit`
- `PZ_UART.runs/impl_1/pz7035_top.ltx`（与新 bitstream 配套的 ILA probes）
- `PZ_UART.runs/impl_1/pz7035_top_routed.dcp`

需要再次从源码重建时，运行 `scripts/fix_rfmc6000_timing.tcl`；脚本会重置综合和
实现 run，完成新实现的 setup/hold 检查后生成 bitstream。之前的源码/工程配置及
实现产物保存在 `backups/before_rfmc_timing_fix.3i0JU8/`。

此报告确认当前已定义约束的内部时序收敛。现有 XDC 尚未定义 AD9361 DATA/FRAME
相对 DATA_CLK 的板级输入延迟，默认 tap 8 也还需要上板 PN/采样窗口验证；不能
将内部时序通过当作板级采样窗口已验证。没有为了消除 no_input_delay 提示编造
外部输入延迟。软件与板卡未在本次操作中烧写。

## 最新 GUI 重建与 XSA 导出

用户重新生成 BD Output Products 后，2026-10-13 15:19 在现有 Vivado GUI 会话
运行 `scripts/rebuild_export_current.tcl`，重新综合、布局布线、生成 bitstream，
并于 15:26 导出包含该 bitstream 的 `pz7035_top.xsa`。本次未刷新模块引用，
使用用户最新生成的 Output Products；保留全部接线、参数和地址映射。

本次整机 WNS +0.183 ns、WHS +0.052 ns、WPWS +0.062 ns，setup、hold、脉宽
失败均为 0；32 组 bus skew 全部通过，最差余量 +3.253 ns。Vivado 界面已打开
最新 implemented design 和 Timing Summary，显示 write_bitstream Complete。

XSA 归档 CRC 校验通过，其中 `pz7035_top.bit` 的 SHA256 与新实现产物完全一致，
`design_1.hwh` 与最新 Output Products 一致。已核对 GPIO 位宽、状态高位填零、
GPIO/DMA 地址和两个 DMA 主口的 MIG 映射。报告与核对记录位于
`reports/gui_rebuild_20261013_151904/`，详细结果见 `xsa_verification.json`。
