# ad9361_rx_axis 重写（2026-10-16）

用户确认范围：只适配当前 config915 的 15.36 MSPS；重写 `ad9361_rx_axis`，保留 BD 端口、寄存器及 DDR 数据格式，Vitis 驱动不变。

## 实现

`PZ_UART.srcs/sources_1/new/ad9361_rx_axis.v` 的接收数据通路从线接口契约重新实现，不实例化旧的 `ad9361_rx_lvds_if`。官方 ADI `axi_ad9361_rx` 和 `up_axi` 保留为寄存器/PN 控制层，第三方源码不改动。

数据通路为 IBUFDS → 7 路可编程 IDELAYE2 → SAME_EDGE_PIPELINED IDDR → 按时间排列的半字窗口 → 完整双通道 IQ 元组 → XPM 异步 FIFO → AXIS。窗口同时识别在两个采样沿结束的 `0,11110000` FRAME 模式，不把 IDDR 的 Q1/Q2 名称直接当成 I/Q。完整元组每 4 个 DATA_CLK 到达，锁定期间还检查半沿位置，检测插入/丢失半字导致的错位。

- 数据符号扩展为 `{Q2[15:0],I2[15:0],Q1[15:0],I1[15:0]}`，TKEEP=FF。
- 默认 FIFO 为 4096 个 64 位元组，默认每 4096 个实际 AXIS 传输产生一次 TLAST（32768 字节）。下游停顿期间数据、TVALID、TLAST 保持稳定。
- ARM 请求锁存到 PL 复位，短脉冲不会因跨域丢失；接收就绪、FRAME 锁定且四个分量使能后启动。ARM 拉低不结束采集。
- ADC 无法被反压。FIFO 满时丢弃完整新元组并锁存 overflow；非法 FRAME 不输出拼接不完整的元组，可重新定位。错误不会静默变成数据完整性通过。
- 调谐发生在 ARM=0；此时仍连续运行 FRAME、PN 及计数器，采集错误 GPIO 不锁存调谐过程中的异常。
- 各时钟域使用 XPM 复位/单比特/Gray 计数器跨域。FIFO 复位、写入数据与使能经过本地同步寄存，避免异步控制直接驱动 BRAM 使能。

## 兼容接口

| 字节偏移 | 保留行为 |
|---|---|
| 0000 | 官方核心版本 |
| 0040 / 0044 / 005C | 官方复位、模式及状态；当前软件写 3 / 0 |
| 0400 + 40×n | 四个分量的通道控制 |
| 0404 + 40×n | PN 状态，bit2:1 写 1 清除 |
| 0418 + 40×n | PN 选择；0 为 AD9361 专用序列 |
| 0800 + 4×lane | lane0..5 数据、lane6 FRAME 的 0..31 taps 及实际读回 |
| 1000 / 1004 | 24 位有效元组计数 / DATA_CLK 周期计数，ARM=0 也增长 |
| 1008 | 签名 41445258 |

沿用 ADI `up_axi` 的完整 32 位写入行为，包括其忽略 WSTRB 的既有行为；这不是新增的逐字节写支持。`adc_ddr_edgesel` 的旧寄存器位仍可访问，接收边界由 FRAME 自动定位。1R1T、其他 FRAME 形式或改变 03D/03E 极性不在本次范围。DATA_CLK 停止时，RX 域状态无法更新；沿用软件计数器无增长检查与 DMA 超时判断。

## 配套约束与 ILA

- `fmcomms3_io.xdc` 将 DATA_CLK 从过时的 245.76 MHz 改为 61.44 MHz；物理引脚及电气设置不变。
- `ad9361_rx_cdc.xdc` 不再引用旧 RTL 层次；XPM 和独立 ADI XDC 负责各自跨域约束，没有添加整组时钟 false path。
- ILA 改为 100 MHz AXIS 域的四个探针：64 位数据、10 位标志、24 位元组计数及 24 位时钟计数。标志低到高为 ARM、TVALID、TREADY、TLAST、ready、locked、active、overflow、frame_error、delay_error。
- 对应构建、采集及波形脚本已同步更新。需要重新生成配套 BIT/LTX，旧的 prefifo 波形文件不适用；当前 ILA 观察已输出的 AXIS 数据，ARM=0 时通过 PN/计数器检查接收。
- 被替换前的工作区版本（含已有未提交修改）备份于 `backups/before_rx_axis_rewrite_20261016/`；旧 LVDS 文件和旧测试主体保留。

## 重现离线验证

在 `zynq/z035` 下运行：

```sh
./tests/run_ad9361_rx_axis.sh
/home/yyz/vivado2020.2/main/Vivado/2020.2/bin/vivado -mode batch -source scripts/verify_ad9361_rx_rewrite.tcl -tclargs /tmp/rx_axis_synth
/home/yyz/vivado2020.2/main/Vivado/2020.2/bin/vivado -mode batch -source scripts/verify_ad9361_rx_integration.tcl -tclargs /tmp/rx_axis_integration
```

仿真使用真实 UNISIM 与 XPM 模型，预期数据由独立的引脚发送器生成。Vivado 2020.2 的 XPM_FIFO 内置 S-5 断言把异步读指针与下一拍的同步结果比较，不适用于其多级 CDC，EMPTY/SLEEP 断言也存在初始化误报；因此设置 FIFO `SIM_ASSERT_CHK=0`，测试另行检查 reset/busy/full/empty 下的读写合法性、完整数据顺序和 AXIS 协议，未替换 FIFO 功能模型。

综合报告仅是离线检查，不等于布局布线或外部 DDR 时序签核。独立模块综合不包含板级引脚和 PS7，因而出现 UCIO-1/ZPS7-1；其 64 条 CDC Warning 来自保留的 ADI 握手/时钟监视器，未发现 Critical CDC。最终回归与集成结果记录在本目录相应日志中。

## 本轮验证结果

Vivado 2020.2 的真实器件/异步 FIFO 模型回归全部通过，日志位于 `simulation/`，没有仿真 Error/Fatal：

| PACKET_SAMPLES | DATA_CLK 反相 | 核对元组数 | 完整分包数 |
|---|---|---:|---:|
| 17 | 否 | 687 | 40 |
| 1 | 否 | 687 | 687 |
| 17 | 是 | 687 | 40 |
| 4096 | 否 | 21167 | 5 |

每组均覆盖版本/签名、24 位计数器及 DATA_CLK/样本的 4:1 单位关系、七路 IDELAY 0/31 档实际读回、AXI-Lite 地址/数据分开到达和响应停顿、AXIS 背压稳定性、符号边界值、ARM 短脉冲锁存、复位重启、未 ARM 时调谐异常、FRAME 半字滑动和非法模式、溢出及恢复、四分量 PN 锁定、错误检测与写 1 清除。仿真将 FIFO 缩为 64 以强制溢出；4096 深度在模块综合中验证。

独立模块综合完成，资源为 1327 LUT、2525 FF、7.5 BRAM tile、7 IDELAYE2、7 IDDR、1 IDELAYCTRL、1 BUFG。CDC 无 Critical；修正同步 FIFO 控制后，没有 BRAM 异步控制 DRC。综合估计存在尚待布局布线处理的 hold 负裕量，外部输入延时也未签核，不能表述为时序收敛。

全工程集成验证也已完成，见 `integration/status.txt` 和 `integration/probe_validation.txt`：在临时副本中刷新模块引用、重新生成 BD 后，`pz7035_top` 综合成功；随后实现 ILA 调试核，并从生成的 LTX 逐位确认四个探针、全部 122 位连接及位序，时钟为 100 MHz。原工程缺少生成后的 `design_1.v`，因此验证脚本自动在副本中生成所需输出产品。

全工程 CDC 报告没有 Critical；综合阶段仍报告 MIG 的 `PLIDC-2`（`DESIGN_1_MIG_7SERIES_0_0_IODELAY_MIG0` 组）及既有 CDC 附件作用域警告，没有在本次 RX 重写中掩盖或调整其他模块。未进行 place/route、生成新 BIT/XSA 或下载硬件；报告中的 LTX/DCP 用于检查，不应与旧 BIT 混用。用户已确认缺少板级到达时间数据，后续通过上板 PN 扫描验证采样余量。

## 当前 SPI 与线接口契约

本次只支持用户确认的 `config915` 工作点。`ad_config.h` 的 `AD_CONFIG_USE_CONFIG915=1` 使 `helloworld.c:929–930` 进入脚本分支；头文件中的 `AD_CONFIG_SAMPLE_HZ=61440000` 属于另一初始化路径，不用于本接收模块的频率依据。

| 项目 | 当前配置及含义 |
|---|---|
| 参考及采样率 | FMCOMMS3 板载 40 MHz 晶体/DCXO；两路 RX 各 15.36 MSPS |
| 时钟链 | BBPLL 983.04 MHz → ADC 245.76 MHz → 122.88 → 61.44 → 30.72 → FIR 15.36 MHz |
| 002 / 003 | DE / DE，两收两发使能 |
| 010 / 011 / 012 | C8 / 00 / 10，2R2T、LVDS DDR、重复 FRAME、无通道交换 |
| DATA_CLK | 标称 61.44 MHz，周期 16.276042 ns；010 bit0 的校准反相不改变频率 |
| 006 | 0F，时钟延时代码 0，DATA/FRAME 延时代码 15 |
| 03D / 03E | 00 / 00，芯片默认数据差分极性反相；CLK/FRAME 不反相 |
| 射频及 BIST | RX/TX LO 为 915 MHz；常态 TX1 BIST 开启，RX 内部 BIST 关闭，RX 接收射频数据 |

配置来源：`vitis_code/key_ctrlll/src/ad_config/config915_data.h:39–42,1584–1591`、`ad_config.c:411–418,448–454,506–527`。最近基线读回见 `reports/spi_config_audit_20261016_160523/README.md:24–44`；后续试验已恢复此基线，见 `reports/blog_timing_trial_20261016_170344/README.md:69–74`。

[ADI UG-570 第 109–112 页及图 79](https://www.analog.com/media/en/technical-documentation/user-guides/AD9361_Reference_Manual_UG-570.pdf)规定每个双通道采样包含八个 6 位半字，按下列时间顺序发送：

```text
DATA : I1[11:6] Q1[11:6] I1[5:0] Q1[5:0] I2[11:6] Q2[11:6] I2[5:0] Q2[5:0]
FRAME:    1        1       1       1        0        0       0       0
```

DATA_CLK 上升沿发出 I 半字，下降沿发出 Q 半字；发送沿与 FPGA 实际采样沿不能混为一谈。解码按采样时间顺序搜索完整 FRAME 序列，并检查后续采样间隔及半沿位置，因此允许时序校准把帧边界移动到任一采样边沿。每路重组为 12 位二补码，再符号扩展到 16 位；AXIS 从低位到高位为 `I1,Q1,I2,Q2`。

本地官方 `reference/rfmc6000_7035/docs/AD9361_Register_Map_Reference_Manual_UG-671.pdf` 第 18 页明确说明默认数据差分极性反相，而时钟及 FRAME 默认不反相。FMCOMMS3 原理图与当前 `fmcomms3_io.xdc:28–45` 保留 P/N，因此接收的六个数据位先逐位 XOR `6'h3F`；这不是对样本做二补码取负。若以后将 SPI 极性改成 03D/03E=FF/0F，必须同步调整此契约。

## 尚待板上验证的时序条件

仿真采用的 4.5 ns 相对延时来自 UG-671 第 6 页的典型值 `15 × 0.3 ns`，只用于协议激励，不是芯片跨工艺、电压、温度的保证值。UG-570 表 51 的默认输出延时范围也不能直接加上这个典型值，作为当前 006=0F 的保证边界。

当前尚缺七路 DATA/FRAME 相对 DATA_CLK 的有效最小/最大到达时间预算，包含 AD9361 已编程延时、子板/FMC/载板走线差、实际抖动及所选 FPGA IDELAY 工作点。因此，修正 `create_clock` 频率、功能仿真通过或内部逻辑时序通过，都不能单独证明外部 DDR 输入建立/保持时间通过。

板上验收还需完成：

- 独立确认引脚 DATA_CLK 频率、差分输入幅度和接收终端；当前 HR Bank 按 1.8 V 配置，保持 `DIFF_TERM=false`，不凭软件结果改成片内终端。
- 在确定的 SPI 与 FPGA taps 下完成 PN 校准，选择连续通过窗口中间位置，回读保存实际工作点，再做长时间 PN 和 DMA 数据连续性验证。
- 取得可依据的每路到达时间边界后，为两个 DDR 发出沿分别补齐 `set_input_delay -min/-max`，检查每个 IDDR 的 setup/hold、时钟不确定度和未约束路径；默认 tap 的静态分析不能代表全部动态校准位置。

硬件校准方法参考 [ADI AN-1441](https://www.analog.com/en/resources/app-notes/an-1441.html)；输入电气与延时原语要求参考 [AMD UG471](https://docs.amd.com/v/u/en-US/ug471_7Series_SelectIO)。本轮未取得新的板上测量前，结论应限定为源码实现与离线验证，不表述为板上 IQ 已验收。

