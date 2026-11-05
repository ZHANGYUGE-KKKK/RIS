# RX diagnostic ABI 仿真结果

2026-10-16 18:04:05 完成；Vivado 2020.2 的真实 UNISIM/XPM 模型，四组全部通过。汇总见 [regression.log](regression.log)。本轮只修改 testbench，未修改 RTL、C 或构建脚本。

| PACKET_SAMPLES | RX_CLOCK_INVERT | AXIS beats | 完整 packet | raw 有效记录 | 独立引脚 payload 检查 | FRAME history 检查 | tag 低 16 位回绕 |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 17 | 0 | 686 | 40 | 7400 | 7328 | 7267 | 0 |
| 1 | 0 | 686 | 686 | 7400 | 7328 | 7267 | 0 |
| 17 | 1 | 686 | 40 | 7399 | 7327 | 7265 | 0 |
| 4096 | 0 | 21166 | 5 | 89320 | 89248 | 89187 | 1 |

新增检查位于 [tb_ad9361_rx_axis_rewrite.sv](../../../tests/tb_ad9361_rx_axis_rewrite.sv)：

- 通过 AXI-Lite 读取 `0x101c`，要求 capability 精确为 `0x00010001`。
- 在相同 FRAME 相位暂停外部 RX 时钟，等待计数器 CDC 收敛后读取两组稳定快照；要求正常接收期间 FRAME rising 增量与 sample 增量精确 1:1，RX clock 增量与 sample 增量精确 4:1，fault 不增长。
- 每组稳定快照要求 FRAME pair 的四个 histogram 总和与 RX clock 总数精确相等，均按 24 位计数器定义比较；检查高 8 位为零。
- 未 arm 时注入非法 FRAME，要求 fault 计数增长，同时 `frame_error`、`delay_error`、`capture_active`、`m_axis_tvalid` 不置位。
- 仅在 raw observation 的 valid 位为 1 时接收记录，要求 payload 无未知位；按 `{raw[31:26], raw[47:32]}` 还原 22 位 tag，逐条检查连续且有序，并在 4096 点配置中覆盖低 16 位回绕。
- 直接从外部差分正端引脚按物理上升/下降沿记录 FRAME 和六位 DATA，用连续八条记录确定初始传输延迟后逐条校验 raw payload。期待值不来自 DUT 解码器或 IDDR 内部信号。
- 在连续锁定期间要求 raw FRAME history 与最近四条记录的 FRAME pair 相符。

原有数据顺序和符号扩展、AXI-Lite、七路 IDELAY 最小/最大值、arm 锁存、AXIS 背压、半字相位滑移、非法 FRAME 拒绝及重新锁定、复位和重新 arm、overflow 后完整性、器件 PN 捕获/错误检测/W1C 检查均保留且通过。

运行方式：

```sh
BUILD_DIR="$PWD/zynq/z035/reports/rx_axis_board_20261016/simulation" \
  zynq/z035/tests/run_ad9361_rx_axis_rewrite.sh \
  > zynq/z035/reports/rx_axis_board_20261016/simulation/regression.log 2>&1
```

这是功能仿真：输入建模为 Fs=15.36 MSPS、DATA_CLK=61.44 MHz、4.5 ns clock-to-data 延迟和六路反相 DATA。它验证给定稳定采样条件下的 ABI、数据和状态机行为，不能代替真实板卡的输入延迟约束、PVT 裕量或硬件 PN 测试；暂停时钟用于获得可严格比较的诊断快照，不代表验证了任意异步时钟中断场景。

目录中的 `rx_rewrite_p17_c0_simulate_353.backup.log` 是此前受限运行环境中、尚未进入 testbench 的 XSim 启动失败记录；本次完整结果以 `regression.log` 和四份当前 `*_console.log` 为准。
