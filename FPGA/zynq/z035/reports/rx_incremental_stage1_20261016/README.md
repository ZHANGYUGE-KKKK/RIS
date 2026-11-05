# AD9361 接收模块增量改写：第一阶段

第一阶段完成：把 LVDS 采样与解帧整理成独立的只接收模块，并验证其 RTL 行为。
Vivado 2020.2 的独立前端仿真、集成回归和独立综合通过。
本阶段没有重新生成整机 BIT、下载 FPGA 或修改板上 SPI；此前的板上 FRAME_ERROR / PRBS 故障仍待验收。

## 这一步改了什么

```text
AD9361 DATA_CLK / FRAME / 六对 DATA
    ↓
ad9361_rx_lvds_if：时钟缓冲 → IDELAY + IDDR → 双沿配对 → 48 位 I/Q
    ↓
现有 ADI 接收寄存器与 PN 检查
    ↓
现有 AXIS 适配、FIFO、DMA
```

原 `ad9361_rx_lvds_if.v` 是 ADI 完整双向 LVDS 模块的副本，只改名并增加调试端口。
本次将其从 626 行整理成 174 行，只保留当前工程实际使用的配置：
`USE_SSI_CLK=1`、`CLK_DESKEW=0`、共享一个 IDELAYCTRL、原生 DATA_CLK 接收。
去掉未连接的发送、TDD、DRP 和其他时钟模式分支。

保留的行为包括：

- ADI 原始 `ad_data_clk` 和 `ad_data_in`；显式指定 `IDDR_CLK_EDGE="SAME_EDGE"`。
- FRAME 与六路 DATA 一致的输入采样路径和前一拍寄存器。
- 原始 `01111 / 00000 / 10011` 解帧条件、I/Q 位序及输出流水级。
- 原始 FRAME 检查与 IDELAY 就绪同步。
- 原生接收流水线的上电初始化行为；ADC 核复位继续由下游 ADI 接收核管理。
- 四个只读调试端口及外层 ILA 的信号名。

`ad9361_rx_axis.v` 只调整这一层的实例连接和说明，公开端口、AXI 地址、64 位数据格式、采集保护、FIFO 和记录器保持原有行为。
原 AXI 寄存器输出 `adc_ddr_edgesel` 留作寄存器映射兼容；官方的这一路 LVDS 实现本就不使用它。
这一步建立清晰、可独立验证的接收基线，没有把代码简化视为板上故障的修复。

源文件：[接收前端](../../PZ_UART.srcs/sources_1/new/ad9361_rx_lvds_if.v)、[外层适配](../../PZ_UART.srcs/sources_1/new/ad9361_rx_axis.v)。
修改前副本保存在本目录的 `*.before` 文件。
Vivado 观察到发送分支移除后，自动将工程中不再使用的 `ad_data_out.v` 标记为 AutoDisabled；官方源文件本身未修改。

## 官方来源

固定提交：`4b12bb58a17edb4c67f63eb367b42d3d3a4e5c91`。
核对了现有 `adi_hdl/SOURCE_MANIFEST.json` 中的 45 个文件，SHA256 全部匹配。
测试对照模块直接编译官方原文件，不使用本次改写的解帧器作为正确答案。

- [ADI axi_ad9361_lvds_if](https://github.com/analogdevicesinc/hdl/blob/4b12bb58a17edb4c67f63eb367b42d3d3a4e5c91/library/axi_ad9361/xilinx/axi_ad9361_lvds_if.v)
- [ADI ad_data_in](https://github.com/analogdevicesinc/hdl/blob/4b12bb58a17edb4c67f63eb367b42d3d3a4e5c91/library/xilinx/common/ad_data_in.v)
- [ADI AXI AD9361 文档](https://analogdevicesinc.github.io/hdl/library/axi_ad9361/index.html)

这里验证的是所需 Verilog 在本地 2020.2 工具中的使用，没有运行需要更新工具版本的完整官方主线工程。

## 独立前端验证

测试台 [tb_ad9361_rx_lvds_if.sv](../../tests/tb_ad9361_rx_lvds_if.sv) 不包含 AXIS、DMA、ARM 或记录器。
将同一组物理 LVDS 激励送给改写前端和未修改的 ADI 接口，逐拍比较 valid、data、status、IDELAY 就绪和延时读回。
另用已知数据的分量关系及递增序号检查 I/Q 拼接和连续性，避免仅因两个实现具有同样行为就认为数据正确。

| 模式 | DATA_CLK | 已知 I/Q 组数 | 检查结果 |
|---|---:|---:|---|
| 2R2T | 约 61.44 MHz | 1024 | 通过 |
| 1R1T | 约 61.44 MHz | 1024 | 通过 |
| 2R2T | 约 245.76 MHz | 1024 | 通过 |
| 1R1T | 约 122.88 MHz | 1024 | 通过 |

同时检查：2R2T 每四个接收周期一组数据、1R1T 每两个周期一组；七路延时独立加载与读回；
损坏一个 FRAME 半周期能报错并在恢复干净输入后恢复状态；IDELAY 复位/恢复；停钟期间流水线不自行前进。

日志：[frontend_simulation.log](frontend_simulation.log)、`frontend_logs/`。

## 外层集成回归

在原 [tb_ad9361_rx_axis.sv](../../tests/tb_ad9361_rx_axis.sv) 中增加可变 RX 时钟周期和定量计数检查。
对已知源时钟测量约 100 us 的 RX 边沿数与样本数，核对两者分别符合时钟频率和 2R2T 的 1/4 速率。
原来只检查计数“有增长”，现在还会检查频率是否正确。

四组回归通过：

- 245.76 MHz 下包长 1、7、4096。
- 61.44 MHz 下包长 7。

覆盖四路 I/Q 次序与符号扩展、样本连续性、TKEEP/TLAST、背压稳定性、溢出停采、帧错误停采、
AXI-Lite 延时配置、四路标准 PRBS 与 AD9361 专用 PN 锁定/错误注入、停钟复位、记录器跨域和独立核复位。

日志：[axis_regression.log](axis_regression.log)、`axis_logs/`。
修改前包长 1 的原回归也运行通过，日志为 [baseline_packet1.log](baseline_packet1.log)。

## 综合验证

脚本 [verify_ad9361_rx_stage1.tcl](../../scripts/verify_ad9361_rx_stage1.tcl) 在内存工程中运行，
不启动主工程的综合/实现，不改动原 BIT/LTX/XSA。

- 纯前端与完整 `ad9361_rx_axis` 均综合通过，没有未解析模块。
- 纯前端包含 7 个 IDDR、7 个 IDELAYE2、1 个 IDELAYCTRL、1 个 BUFG，无锁存器。
- 前端独立综合使用 4.069 ns DATA_CLK、5 ns REF、10 ns UP 时钟；综合估计 WNS 为 +2.237 ns。
- 这是独立综合估计，未布局布线、未施加实际板级输入时序预算，不能作为最终时序或 LVDS 眼图验收。

日志：[synthesis.log](synthesis.log)、[frontend_structure.txt](frontend_structure.txt)、
[前端资源](frontend_utilization.rpt)、[外层资源](axis_utilization.rpt)。
工具日志包含本地 Tcl Store 无写权限的环境提示、OOC 时钟位置未指定提示，以及所保留官方文件的既有告警；
本轮没有改动官方文件以消除这些告警。

## 目前可以得出的结论与后续门槛

可以确认：在有效的模拟 LVDS 输入下，整理后的采样、配对、解帧与官方实现逐拍一致，
已知 I/Q 顺序与连续性正确，模拟 PRBS 能锁定且能发现注入错误，计数路径在理想时钟下正确。

尚不能确认：实际 DATA_CLK 是否具有预期频率与波形质量、本板的有效采样延时、实际 PRBS 能否通过。
板上此前的 PRBS 失败结果仍然有效；仿真通过不能覆盖实际引脚、终端、供电和输入时序。

下一增量应使用匹配的新 BIT/LTX 在 ARM=0、DMA 停止条件下验证实际 PRBS 和时钟，
前端通过后再推进打包和长段 DMA 数据连续性验收。

复现：

```bash
bash zynq/z035/tests/run_ad9361_rx_lvds_if.sh
bash zynq/z035/tests/run_ad9361_rx_axis.sh
/home/yyz/vivado2020.2/main/Vivado/2020.2/bin/vivado -mode batch -nojournal -nolog \
  -source zynq/z035/scripts/verify_ad9361_rx_stage1.tcl
```

上述命令从仓库根目录执行。XSim 在本环境中需要允许本地仿真内核通信。
机器可读结果、源文件校验值和验证范围见 [verification.json](verification.json)。
