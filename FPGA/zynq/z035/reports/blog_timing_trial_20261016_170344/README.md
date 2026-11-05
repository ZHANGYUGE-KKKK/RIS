# 用户所给文章的核对与 LVDS 延时试验

2026-10-16，xc7z035 / AD9361，使用板上原 FPGA 镜像与现有 ARM 驱动。

**结论：文章中的寄存器解释存在明确错误，不能直接用于当前 LVDS 工程。按正确字段试验其“调整采样位置”的思路后，96 组组合均未通过 PRBS，没有得到可保留的修复配置。所有修改的配置已恢复并回读核对。**

## 文章核对

[原文](https://blog.csdn.net/weixin_42550052/article/details/160432413)讨论 CMOS 接口，当前工程使用 LVDS DDR。文章网页已成功读取，以下解释逐项对照 ADI 定义，不采用文章的寄存器注释。

| 文章建议 | ADI 实际定义及当前工程影响 |
|---|---|
| 写 010=33，声称设置 DDR 与驱动增强 | 010 是 IQ/通道交换、FRAME 模式、总线位序和时钟反相等控制；DDR 由 012 bit5 控制。不能按文章注释使用 |
| 用 010 bits[5:4]、[7:6] 做 200 ps 步进相移 | 分别是收发通道交换、收发 IQ 顺序控制；不是相位延时字段 |
| 写 011=1F，声称 FRAME 延时补偿 | 低两位是数据相对 FRAME 的整/半周期延迟；bit2 是 FRAME 反相，bits3/4 作用于 TX。整个字节不能视作精细相位值 |
| 写 012=82，声称设置 6 bit 重组超时 | 该寄存器没有这个超时字段；bit4 被清零会切换到 CMOS，破坏当前 LVDS 模式 |
| 010 从 33 改 3B，声称增强低温驱动 | 改变的是 bit3：RX_FRAME 模式，不是驱动能力 |
| 固定 IDELAY 为 10 taps | 可以测试延时思路；当前设计已经具备七路 IDELAY，直接通过现有控制接口设置即可，无需新增器件或重烧 FPGA |

文章 IDELAY 示例选择 `DELAY_SRC="IDATAIN"`，却只展示连接 `DATAIN`；按示例所示接线不能直接使用，应连接所选的 `IDATAIN` 路径。当前官方 `ad_data_in` 已正确连接，无需照搬该片段。

本轮没有执行文章的 010=33、011=1F、012=82，也没有改动串联电阻、电容、接口标准或终端设置。
正确的亚周期 RX 时钟/数据延时寄存器是 **006**；FPGA 侧则使用现有 IDELAY。

依据：

- [ADI no-OS 官方寄存器定义](https://github.com/analogdevicesinc/no-OS/blob/main/drivers/rf-transceiver/ad9361/ad9361.h)，`REG_RX_CLOCK_DATA_DELAY` 与 `REG_PARALLEL_PORT_CONF_1/2/3`。
- [UG-671 本地官方文档](../../reference/rfmc6000_7035/docs/AD9361_Register_Map_Reference_Manual_UG-671.pdf)，文档第 6 页 RX 延时、第 9–10 页并行端口定义。
- [ADI AN-1441：LVDS PRBS 校准](https://www.analog.com/en/resources/app-notes/an-1441.html)。

## 实际进行的板上试验

通过临时放入 PS DDR 的诊断程序调用现有 ARM 驱动的 SPI、IDELAY 和 PN 检查函数。
运行前核对现有 ELF 哈希、内存中的 main 指令和 CPU 停留位置。ARM=0，采集未启动，没有执行 DMA 采集或 FPGA 重新编程。

基线读回：006=0F、010=C8、011=00、012=10；七路 FPGA taps 全为 0。
临时设置 RX PRBS：3F4=09、3F5=00、3F6=00，使用原程序配置的四路 AD9361 PN 检查器。

96 组试验为以下参数的笛卡尔积：

| 参数 | 取值 | 数量 |
|---|---|---|
| FPGA 输入延时 | 原值；仅 DATA0=10；六路 DATA=10、FRAME 原值；DATA+FRAME 七路均为 10 | 4 |
| DATA_CLK 反相 | 010=C8 / C9，只改变 bit0 | 2 |
| RX 时钟/数据细延时 | 006=0F / 04 / 88 | 3 |
| 数据相对 FRAME 延时 | 011 bits[1:0]=0 / 1 / 2 / 3，保留其他位 | 4 |

每组写入后回读 SPI；IDELAY 使用原驱动的写后回读接口。
每组等待 2 ms，进行约 5 ms 的内部边沿计数，然后观察 PN 10 ms。
如果找到通过点，程序会追加 100 ms 确认；本轮没有通过点，因此没有进入长确认。
保持 012=10，未改变 LVDS 模式、PLL/采样率、LVDS 极性或驱动幅度。

## 结果与边界

- 3 次基线 PRBS 检查及 96 组组合检查，**99 次全部返回 -4（PN 数据不匹配/失步）**。
- 所有 PN 检查点的四路通道状态均为 02，表示 PN out-of-sync。采样/边沿计数均有增长，未触发“无数据”返回值。
- 所有 100 条记录（含恢复后的 1 条普通接收计数记录）中，012 均为 10，05E 均为 80。
- 恢复后的普通接收记录未执行 PN 检查，CSV 中以 -999 标记，不能计为一次 PN 失败或成功。
- GPIO 观察值为 01 / 03，bit1 是瞬时接口状态。ARM=0 时错误锁存不用于验收，不能据此宣称 FRAME_ERROR 已消失。
- 未抓取新的 ILA、未取得长时间 DMA IQ 数据；本次仅是接口 PRBS 短测试，不构成长期连续性验证。
- 内部边沿估算已保存在 CSV，仅用于对比；它不能代替引脚频率与波形测量。

由此只能判断：**文中固定 10 taps 及本轮所测延时组合没有修复当前接收错误**。
这不排除其他时序、格式、极性、物理连接或 PN 检查配置问题，也不能单凭全失败就认定 AD9361 芯片或时钟源损坏。
后续优先在 FPGA 接收端同时核对 DATA_CLK 与 RX_FRAME/RX_DATA 的相对边沿、差分幅度及终端，结合独立参考时钟的测量区分输入波形问题与内部计数问题。

## 恢复核对与产物

- 修改的 006、010、011、3F4、3F5、3F6 已恢复；恢复返回值为 0。
- 前后读取的 99 个 SPI 寄存器（000..05F、3F4..3F6）全部相同。
- 七路 FPGA 延时恢复为原来的 0；核对 core reset/control 前后相同。
- 最终 ARM=0、GPIO=03，READY=1、ACTIVE=0，错误锁存位为 0。
- CPU 通用寄存器、CPSR、PC 恢复，移除临时硬件断点并继续运行。
- 原 BIT、LTX、ELF、当前 RTL、XDC、config915 等 16 项文件哈希与各自最近报告一致。本轮新增内容仅在此报告目录；未修改工程源文件或初始化脚本。

原始记录：[trial.log](trial.log)、[rows_trials.bin](rows_trials.bin)、前后 SPI/状态快照。
解析：[analysis.json](analysis.json)、[trial_points.csv](trial_points.csv)、[artifact_hashes.json](artifact_hashes.json)。
离线核对：`python3 analyze.py`，仅读取本目录文件，不访问硬件。

诊断源码为 [trial.c](trial.c)，JTAG 操作为 [run_trial.tcl](run_trial.tcl)。绝对函数地址和入口依赖当前原 ELF，应用重新链接后不能直接复用。
最初三次连接准备失败（目标枚举、PL 地址访问映射、CPU 已停止）发生在写入 SPI 之前；已分别保留日志，最终试验以 `BLOG_TIMING_TRIAL_COMPLETE` 正常结束。
