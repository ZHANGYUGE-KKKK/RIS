# RIS 控制与射频采集验证工程

## 项目简介

本工程围绕可重构智能表面（RIS）开展 FPGA 控制与射频接收验证，目标是在 Zynq 平台上实现 RIS 状态控制、AD9361 双通道 I/Q 接收、DDR 缓存及后续数据分析。

当前主工程位于 `zynq/z035`，对应 **PZ7035-FH / xc7z035ffg900-2**，使用 **Vivado / Vitis 2020.2**，分支为 `PZ035`。当前射频子板为 **AD-FMCOMMS3 Rev.A**，使用板载 40 MHz 晶体；仓库同时保留 RFMC6000 参考资料、早期接收实现和 ZC706 验证工程。

> 当前状态：**FRAME_ERROR 待解决，PN 校验尚未通过，有效 I/Q 连续采集和射频回接尚未完成验收。** PLL 锁定、MIG 自检或 FPGA 内部时序通过，均不能单独作为接收数据正确的证明。

FPGA PL 端包含以下部分：

1. **5 × 5 RIS 控制输出**：共 25 路，支持按键消抖控制、PS 独立设置各路电平，以及 RTL 产生的 1 MHz 同步方波模式。
2. **AD9361 接收前端**：接收 DATA_CLK、RX_FRAME 和 6 对 LVDS 数据，移植 ADI 接收逻辑，提供双通道 I/Q 解帧、输入延时配置和 PN 监测。
3. **采集与缓存通路**：四个 12 位 I/Q 分量符号扩展至 16 位，组成 64 位 AXI Stream，经异步 FIFO、AXI DMA SG 写入 MIG 管理的 PL DDR。
4. **PL DDR3 控制器**：提供 1 GiB 地址窗口，供 CPU、DMA 描述符和采样缓冲区访问。
5. **控制与调试接口**：AXI GPIO、接收核 AXI-Lite 寄存器及 ILA，用于观察 RIS 控制、FRAME、I/Q、采集状态和跨时钟域记录。

PS 端为 Cortex-A9 裸机程序，包含 AD9361 SPI / RESETB、射频配置、RIS GPIO、接收状态、MIG 内存管理和 SG DMA 驱动。当前默认启用 `AD_CONFIG_USE_CONFIG915=1`，执行嵌入的 CONFIG915 操作表，配置 RX / TX 约 915 MHz、采样率约 15.36 MSPS，并进行 PN 检查和延时扫描。默认流程结束时保持采集 `ARM=0`，TX1 BIST 测试音保持开启；具体配置与板测结果见 [CONFIG915 说明](zynq/z035/reports/config915/README.md)。

工程入口为 [PZ_UART.xpr](zynq/z035/PZ_UART.xpr)，RTL 顶层为 [pz7035_top.v](zynq/z035/PZ_UART.srcs/sources_1/new/pz7035_top.v)，Vitis 应用为 `key_ctrlll`，程序入口为 [helloworld.c](zynq/z035/vitis_code/key_ctrlll/src/helloworld.c)。

## 目录结构

| 目录 / 文件 | 说明 |
| --- | --- |
| `fmc_drive_board/` | RIS FMC 驱动板硬件设计，包含嘉立创EDA 工程、电源设计说明、核对脚本和参考资料。 |
| `docs/` | RFMC6000 接收采集架构、容量预算和早期硬件通路说明。 |
| `zynq/z035/` | 当前 PZ7035-FH 主工程，包含 Vivado 工程文件及硬件导出文件。 |
| `zynq/z035/PZ_UART.srcs/` | RTL、Block Design、IP 配置和 XDC 约束；`sources_1/adi_hdl/` 保存移植的 ADI HDL 及来源记录。 |
| `zynq/z035/vitis_code/` | Vitis 工作区，包含硬件平台 `key_ctrl`、当前应用 `key_ctrlll` 和其他参考工程。 |
| `zynq/z035/vitis_code/key_ctrlll/src/ad_config/` | AD9361 配置、参考 no-OS 驱动及 CONFIG915 操作表与执行器。 |
| `zynq/z035/vitis_code/key_ctrlll/src/drivers/` | SPI、RIS GPIO、接收控制、MIG 和 DMA 驱动，接口约定见 [驱动说明](zynq/z035/vitis_code/key_ctrlll/src/drivers/README.md)。 |
| `zynq/z035/scripts/` | Vivado 工程配置、综合实现、XSA 导出、硬件检查和 ILA 抓取脚本。 |
| `zynq/z035/tests/` | 接收前端、AXI Stream 打包及采集控制仿真，包含官方参考逻辑和故障注入检查。 |
| `zynq/z035/reports/` | 各阶段构建、配置、板测和故障分析记录；当前重点见 [官方接收前端移植](zynq/z035/reports/ad9361_official_port/README.md)及 [FRAME_ERROR 与 I/Q 连续性板测](zynq/z035/reports/frame_error_continuity_20261016_140342/README.md)。 |
| `zynq/z035/reference/`、`zynq/z035/backups/` | 参考源码、资料及历史修改快照，用于核对和追溯。 |
| `zynq/zcu706/ris_board_test/` | ZC706 平台 RIS 驱动板引脚与时钟输出验证工程，具体连接与当前 PZ7035-FH 主工程分别维护。 |

## TODOLIST

以下状态依据仓库中截至 **2026-10-16** 的源码与验证记录整理。

| 状态 | 说明 |
| --- | --- |
| `已实现` | 搭建 PZ7035-FH 的 PS / PL 主工程，加入 25 路 RIS 输出及按键、PS、1 MHz 方波控制模式。 |
| `已验证` | 打通 AD9361 SPI 与 RESETB，执行 CONFIG915 操作表并完成校准等待及 PLL 锁定检查。 |
| `已实现` | 搭建 LVDS 接收、64 位 I/Q 打包、跨时钟域 FIFO、AXI DMA SG 与 MIG DDR 通路及配套裸机驱动。 |
| `已验证` | 移植 ADI 接收前端，通过包长、背压、错误注入、PN 监测和调试记录回放等 RTL 仿真检查。 |
| `已验证` | 当前官方接收前端版本完成综合、布局布线及内部时序 / CDC 检查，导出匹配的硬件平台；板上 MIG 自检记录为 9 / 9、0 错误。 |
| `待解决` | 接收接口存在 FRAME_ERROR、PN 失步及异常数字计数，需继续核对实际时钟、FRAME、LVDS 电气条件与并行口配置。 |
| `待完成` | PN 通过后，验证 SG DMA 有限窗口采集的 I/Q 顺序、符号、样本数量和数据连续性；当前默认缓冲区配置为 256 包 / 8 MiB。 |
| `待完成` | 验证 TX1A 经外部 30 dB 衰减器回接 RX1A 的真实射频收发，使用有效 I/Q 检查约 960 kHz 测试音。 |
| `待完成` | 完成采样数据导出与上位机分析，并验证 RIS 状态切换与采集窗口的对应关系。 |

## 维护约束

- 保持根目录清晰、可读；新增源码、资料和验证记录优先归入已有功能目录。
- 临时文件、工具缓存和编译产物按 `.gitignore` 管理；需要保留的调试证据放入对应的 `reports/` 子目录，并注明配置、时间和结论。
- Vivado 导出的 XSA、实际下载的 BIT / LTX、Vitis 平台及 BSP 应保持匹配。修改硬件后同步更新平台和 BSP，再重新编译应用。
- 修改射频配置、FMC 引脚或时钟方案时，同步更新说明；区分当前 FMCOMMS3 配置、RFMC6000 参考方案和历史实验参数。
- 分别记录仿真、内部时序、内存自检及实际接收数据的验证结果。采集失败或 PN 未通过时，缓冲区内容只作为调试资料，不标记为有效射频采样。
- 驱动与应用保持清晰分工；板级 SPI / GPIO 访问、射频配置和采集流程分别维护，避免重复初始化或无意覆盖配置。
- README 和新增文档优先使用仓库内相对链接，避免依赖本机绝对路径。
