# MT 离线验证记录

最终验收数据和源码/产物校验值见 `verification.json`。

- `python_tests_isolated.log`：上一轮 9 个模块、79 项测试全部通过。GUI 测试使用临时存储与模拟板卡，不访问真实网络设备。
- 本轮改为“周期内回绕”后，`mt_wrap_tests.log` 的 10 项编译测试和 `mt_wrap_gui_tests.log` 的 6 项 GUI 测试重新通过；其余 64 项沿用未受本次改动影响的上一轮结果。当前共 80 项。
- `protocol_tests.log`：C 协议解析、MT 上传顺序/校验/取消、旧控制命令回归和 512 字节应答边界通过。
- `mt_unisim.log`：本轮重新运行 Vivado 2022.2 官方模型，验证 `(50,80)` 在本周期内回绕、后续零占空比周期不受影响、循环衔接，以及初始时延、50 片 595/400 输出、最短时段、停止/复位。
- `fast_unisim.log`：MT 集成后的原方波与普通帧共享输出路径通过。
- `axi_unisim.log`：16 帧配置的原 AXI/序列/流式/错误处理回归通过。
- `hardware_build.log`：最终硬件构建和导出成功；`timing.rpt` WNS +0.018 ns、WHS +0.064 ns，0 个失败端点。
- `drc.rpt`：0 项违规；`cdc.rpt`：210 个跨时钟端点均为 Safely Timed，无 Unsafe/Unknown。
- `firmware_build.log`：最终 XSA 对应的 Vitis 2022.2/lwIP 1.8 固件构建成功；3 条 fall-through 警告来自厂商 lwIP xadapter.c，应用源码无编译警告。

仿真环境使用已有编译器，通过临时目录映射满足 xelab 的固定编译器路径；没有安装软件或改动系统目录。
UNISIM ODDR 自带 100 ps 的 C-to-Q 延迟，首边沿断言对此留出容差；相邻边沿间距仍按 300 MHz 时钟精确检查。
早期失败/中间日志归档在 `build/mt_diagnostics/`，不作为最终验收结果。

没有进行板卡下载、示波器实测或 MATLAB 本体执行。MATLAB 示例文本已由上位机解析与波形编译测试覆盖。
本轮修正发生在上位机将 M/T 编译为时段的步骤；硬件和固件仍按时段播放，源代码与 BIT/ELF 未改变，无需重新生成板端包。
