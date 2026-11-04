# 2026-10-30 RTL验证记录

此文保留当时状态。2026-11-02已接入C固件与TCP/GUI完整链路，见 [新增验证记录](firmware/validation.md)；下文“尚未接入”不代表最新进度。

独立目录内实现QAM1图案播放器，原工程40个RTL/约束/脚本文件指纹保持一致。未安装新软件，未连接、下载或烧写板卡。

## 结果

| 检查 | 结果 |
| --- | --- |
| 全码本00–FF | 1119幅图案、26,103个RLE时段全部通过50片独立595模型；K=1全符号，K=2多字节/循环另测 |
| 数据/时钟 | 每片独立字节、MSB先发；每组8个SHCP脉冲；高低各至少5 ns；DS建立至少一个300 MHz时钟 |
| 状态/保护 | 单次完整周期后保持、STOP完成当前突发、400位稳定读回、预检取消、复位、禁止运行时上传/切换、末字填充拒绝 |
| 预检 | 描述边界、图案id、零时长、符号周期不等于L均在取得IO前拒绝 |
| 旧功能 | 统一MT、1/3/5 MHz及自定义全板高速、普通595、AXI队列/序列/流模式回归通过 |
| 完整AXI路径 | FAST关闭及开启两种配置均通过；包含新QAM寄存器、非法访问无副作用、上传及400位实际锁存 |
| 离线编译器 | 8项测试通过：校验和、表边界/周期、硬件容量、拒绝隐式改速、防覆盖及完整图案还原 |
| Vivado实现 | xc7z045ffg900-2，综合/布局/布线及布线后物理优化完成；当前RTL/约束SHA-256与构建记录一致 |
| 时序 | WNS +0.002 ns，TNS 0；WHS +0.022 ns，THS 0；无未约束内部端点 |
| DRC | 无Error/Critical Warning；保留1条PLBUFGOPT-1 Warning，物理优化复制时钟缓冲后存在串接BUFG，已包含在完整时序分析中 |
| CDC | 报告1850个跨时钟端点均为Safely Timed，未加入跨时钟false-path例外 |
| 资源 | LUT 13,423（6.14%），FF 18,160（4.15%），BRAM 64.5（11.83%），DSP 0 |

当前建立时间余量仅2 ps，后续任何RTL/约束/实现设置修改都必须重新检查，不能将本检查点的结果外推。板级电气建立保持、595链路及RIS响应/射频效果尚未验证。

## 文件与复现

- `export_qam/ris_ctrl_unit.bit`、`ris_ctrl_unit.xsa`：当前通过实现检查的输出，未下载。
- `export_qam/build_manifest.json`：输出文件、RTL/约束与报告的SHA-256指纹。
- `reports/qam/timing.rpt`、`drc.rpt`、`cdc.rpt`、`utilization.rpt`：完整实现报告。
- `reports/qam/hardware_build.log`：最终从同源码布线检查点继续物理优化并导出成功；包含`RIS_QAM_BUILD_PASS`。
- `reports/simulation`：Icarus、原版ODDR/glbl模型、AXI及编译器测试记录；机器可读清单在`reports/validation.json`。

从源码重新运行 `bash scripts/build_qam.sh`，遇到时序差距会执行布线后AggressiveExplore物理优化，再检查时序/DRC/源码指纹，成功后导出并记录指纹。`scripts/refine_qam.tcl`为本次从已有布线检查点继续的入口，运行前也检查源码指纹。

`bash tests/run_sim.sh icarus`和`vendor`均通过。`vendor`使用本机Vivado原版ODDR/glbl源模型及功能MMCM时钟模型。XSim因系统缺少`/usr/bin/gcc`未完成链接，未作为通过项；未声称完成SDF仿真。

## 尚未接入的部分

板端C固件和TCP/UART协议尚未新增QAM上传、能力协商、START/STOP及400位镜像交接。GUI继续保持实时播放能力门控，只能通过已接入的FRAME核线。离线编译器不会连接硬件，也不生成START操作。

原1 MHz/L=256码本原速参数被拒绝；本轮数字夹具明确设为60 tick/片，即200 ns/片和19,531.25 Hz PWM，不代表原码本射频/EVM性能在改速后成立。
