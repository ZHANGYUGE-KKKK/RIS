# 2026-11-02完整控制链路验证

本文记录构建与模拟验证阶段；后续已完成实板Flash烧写、两次完整读回与断电启动验收，见 [实板记录](../flash/FLASH_REPORT.md)。下文未烧写的描述保留为当时测试范围。

实现范围为GUI、不可变上传快照、TCP QAM1协议、真实板端C解析/驱动与既有QAM1 AXI播放器。所有修改位于`ris_control_ui_v2/`，未下载板卡、改写QSPI或进行射频测量。

## 已完成检查

| 检查 | 结果与证据 |
| --- | --- |
| 全部Python/Tk回归 | 104项通过，`../../../full_chain_tests.log`；覆盖旧控制与新增完整链路 |
| 最终QAM专项 | 27项通过，`../../../qam_chain_final_tests.log`；包括最后新增的两个取消/非法请求边界 |
| 真实TCP整链路 | 真实Tk、工作线程、RisClient TCP客户端、本地TCP服务、真实C协议解析与真实C驱动；仅AXI/板卡用模型替代 |
| 完整码本上传 | 1119幅图案、26103段、256项符号描述及payload；客户端与固件CRC一致，全部请求小于160字节 |
| 启动与取消 | 只有总按钮可启动；上传/启动应答期间取消均确认STOP；坏应答不重试、不继续START |
| 数据保护 | 错误CRC、偏移跳跃/重复、错序、缺块、非法HEX、错误符号周期均不能启动；断线使未完成事务失效 |
| 模式交接 | QAM停止后完整400位物理锁存模型与普通控制镜像相符；可再全板、FAST及重新QAM；旧BIT/MT/FAST协议回归通过 |
| 独立配置 | 上传期间编辑草稿不改本次CRC、payload、K或循环；原速不兼容/旧固件在输出变化前拒绝 |
| 离线编译器 | 8项通过，`offline_compiler_tests.log`；拒绝隐式改速，保留来源ZIP与独立MMIO编译入口 |
| RTL最终复测 | `bash tests/run_sim.sh vendor`通过QAM、统一MT、FAST、普通595及FAST关闭/开启两组AXI测试；`../simulation/vendor_chain_regression.log` |
| ARM网络固件 | Vitis 2022.2 / Cortex-A9 / lwIP211 v1.8编译通过，`build.log`含`RIS_NETWORK_APPLICATION_BUILD_PASS` |
| 产物配对 | BIT与XSA内嵌BIT逐字节一致，PS初始化匹配，导出ELF与实际应用ELF一致，固件源与Vitis复制源一致 |
| 来源保护 | 原RTL/约束/脚本40文件与原控制台清单40文件均SHA-256一致；用户MATLAB变动未处理 |

最新两个边界用例是：启动应答刚返回时取消，仍必须收到成功STOP才报告已取消；无效QBEGIN/未知Q命令不改变正在运行的BLINK。

本地AXI模型不是RTL协同仿真，不验证DDR、以太网PHY、实际AXI时延或IO电气。它运行与ARM ELF相同的C解析器和驱动源码，并对400位停止交接作断言。实际RTL与595链路另由数字测试台覆盖。

RTL复测使用本机Vivado原版ODDR/glbl与功能MMCM模型。完整00–FF码本的26103个事件逐次核对50片独立595数据及锁存间隔，K=1覆盖所有符号，K/多字节/循环另有短夹具；没有省略短脉冲。完整AXI测试还检查新寄存器、非法上传无副作用与400位实际锁存。未执行SDF仿真，XSim仍因本机缺少系统gcc而未列为通过项。

## 硬件与产物

本次未改变已通过实现的RTL/约束，沿用2026-10-30布线结果，并重新核验源SHA-256和BIT/XSA配对。WNS +0.002 ns、WHS +0.022 ns，无路由错误、无DRC Error/Critical Warning；保留PLBUFGOPT-1 Warning。2 ps建立时间余量很小，不能据此替代板上验收。

`export_qam/`内：

- `ris_ctrl_unit.bit`、`ris_ctrl_unit.xsa`：匹配QAM1硬件。
- `ris_all_io.elf`、`ps7_init.tcl`：新网络固件与匹配初始化。
- `build_manifest.json`、`firmware_manifest.json`、`manifest.json`：来源、编译宏与产物SHA-256。

运行 `python3 scripts/verify_package.py` 可只读复核全部配对及寄存器头文件一致性。手动下载入口`scripts/program_board.tcl`已准备但未执行；构建/验证脚本不会自动调用它。

## 实际能力边界

实时payload最多4096字节，完整重传F/E/S/P后才启动；不支持流式补数据、仅更新数据RAM或暂停续播。连接/断线只撤销未完成事务，已启动FPGA播放继续。

原1 MHz/L256码本仍被严格拒绝。明确选择200 ns/片低速数字核线时，实际PWM19,531.25 Hz、K=3对应约6,510.4167 Baud。改速不验证来源码本的射频/EVM结论。当前报告没有声称已在板上收发256QAM。

操作步骤与TCP数据布局见 [完整链路说明](../../../docs/qam256_end_to_end.md)。
