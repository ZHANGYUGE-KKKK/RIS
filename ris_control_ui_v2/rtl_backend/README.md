# RIS 256QAM独立RTL副本

原工程为 `/home/wenhan/PROJECTS/RIS/zynq/zc706/ris_ctrl_unit`。本目录复制其RTL、约束与RTL测试后独立修改；`original_sha256.json`记录原文件指纹。所有生成的Vivado工程、报告和输出均在本目录内，未修改旧工程，未连接或下载板卡。沿用本机SOFTWARE内的工具链，无新增安装。

新增 `rtl/ris_qam_player.v`，通过 `ris_fast_io.v` 与原统一MT/全板通路互斥使用同一组IOB输出。50条DS各自发送一个8位芯片字节，MSB先发，Q0–Q7对应字节bit0–bit7；10组SHCP/STCP仍每组服务5片595。普通控制器会等待MMCM锁定后再开始初始化，避免丢失初始脉冲。每次更新8个100 MHz SHCP脉冲，随后锁存，流水线对齐全部输出。数字仿真要求SHCP高/低至少5 ns、DS在下一上升沿前至少一个300 MHz时钟建立。

内存容量：2048幅400位图案、32768个RLE时段、256个符号描述、4096字节数据序列。K范围1–1,000,000；每字节的PWM周期重复K次，再进入下一字节；循环作用于整个数据序列。相邻重复图案仍按时序锁存，不合并或省略短时段。单次播放和STOP保持最后锁存的完整400位状态，RELEASE才归还普通控制通路。

**本目录已接入RTL、AXI寄存器、板端C驱动与TCP QAM1协议，GUI总按钮可完整上传并启动。配套镜像已完成Flash烧写、两次完整读回和断电启动验收。不能把旧固件的统一MT能力当作独立QAM播放能力。** 使用与协议见 [完整链路说明](../docs/qam256_end_to_end.md)。UART仍保留原全板命令，不承载QAM表上传。

## 时序与码本限制

300 MHz引擎一tick为10/3 ns。QAM1要求 `slot_ticks` 为60–1,000,000的整数，即最短200 ns/片；每事件持续正整数片。一个符号内所有事件片数之和必须等于L。没有自动延长、舍弃或量化不兼容事件。

现有1 MHz、L=256码本需要75/64 tick/片，且最短变化间隔3.90625 ns，不能由此硬件原速播放。明确将其设为60 tick/片，仅用于低速数字/接线试验时，实际PWM频率为19,531.25 Hz，K=3时符号率6,510.4167 Baud，裸速率52,083.3333 bit/s；这改变了调制条件，不能沿用原模型的射频/EVM结论。200 ns也是数字接口设计限值，板上建立保持、RIS响应及射频性能仍需实测。

## 上传与播放顺序

AXI基址沿用 `0x41200000`。新区域为 `0x0200–0x02bf`，不占用原有 `0x0100` 暂存窗口。全部写操作仅接受对齐的单次32位访问和 `WSTRB=0xf`；新区域不支持AXI burst。非法写返回SLVERR且不更新计数/数据。

1. 停止原普通控制和统一MT，确认两者不再驱动时钟；释放统一MT对IO的占用。按实际需要设置MR/OE，上传或预检本身不改变OE。
2. 确认QAM未占用且不忙，向CONTROL写16清空四个上传计数。该操作只清计数，未初始化RAM不能被播放；已完成时的错误码保留到下次START或复位。
3. 设置SLOT_TICKS、K、L。依次向FRAME_DATA写图案，每帧13个小端32位字，末字高16位必须为0；向EVENT_DATA写 `{持续片数16位, 图案id16位}`；向SYMBOL_DATA按00–FF顺序写 `{段数16位, 首段索引16位}`；向PAYLOAD_DATA逐字节写入低8位。
4. 检查四个上传计数。FRAME_COUNT高4位是当前帧已写字数，必须为0；低12位是完整图案数。图案/事件/数据不可为空，符号表必须恰好256项。超容量写被拒绝。
5. 用户总下发入口应用配置时，CONTROL写1单次或2循环。START先冻结配置和上传，再预检全部256个符号，包括未被当前payload使用的符号。检查描述边界、有效图案id、正时长及周期片数总和。失败不占用IO、不产生移位/锁存脉冲；从ERROR读取原因。
6. 轮询STATUS；pending只表示控制请求尚未跨时钟接收，不能代替busy/running。预检时bit2置1，播放bit1置1，占用bit0置1，错误bit4置1。首次输出在预检/预取完成后开始，没有承诺与START写入边沿固定相位。
7. 停止须向**QAM CONTROL**写0；预检中取消后不占用IO，播放中完成当前8位突发及锁存后停止。停止不会补发全0图案。等待busy/running/pending全0后，可从HELD_FRAME读回13字稳定状态；普通控制器的内部镜像须与该400位状态对齐，再写8释放IO。释放/切换不得产生额外SHCP/STCP边沿。

在START接受至RELEASE完成之间，配置和所有RAM上传写均被拒绝。旧高速控制写也被拒绝，防止两个引擎同时接管。修改参数需先停止并释放。外部MR、MMCM失锁或总复位会取消播放并使上传计数失效，需重新上传；MR和输出禁止仍按原普通控制器控制。

完整常量见 `include/ris_qam_regs.h`。错误码：1符号描述越界/空，2图案索引越界/零持续片数，3周期不等于L，4预取欠载（停止并保持，不拉长时段）。配置跨时钟采用冻结数据+请求/应答握手，RAM读端两级流水，上传写控制先寄存；状态使用同步器。停止后的完整图案只在稳定窗口读取，运行中的多字读不是快照。

## 编译与验证

```bash
cd /home/wenhan/PROJECTS/RIS/ris_control_ui_v2/rtl_backend
bash tests/run_sim.sh icarus
bash tests/run_sim.sh vendor
bash scripts/build_qam.sh
bash scripts/build_firmware.sh
```

`icarus`使用本地RIS-Validation；`vendor`在Icarus中直接使用本机Vivado的原版ODDR与glbl模型，MMCM使用固定100→300 MHz功能时钟模型。原版ODDR模式包含全局启动复位。`xsim`另保留完整Vivado仿真入口，但本机XSim因缺少`/usr/bin/gcc`无法完成链接，本轮不将其列为通过项。所有数字仿真不等价于SDF延迟或板级时序验证。

Icarus不支持旧core的命名结构体数组语法；测试脚本仅在`build/simulation`生成按同一908位布局展开的副本，Vivado仍直接综合原始core。

测试覆盖50片独立595模型、不同字节/位序、脉冲间隔、完整400位保持、K/多字节切换、循环、STOP、非法上传/预检、旧模式互斥及复位；真实码本00–FF测试使用明确改速的数字夹具。旧MT、全0/全1高速及普通595测试保留。

硬件脚本建立新的 `vivado_qam` 工程，仅在布线时序与DRC通过后生成 `export_qam/ris_ctrl_unit.bit` 和XSA；失败保留检查点及报告，不导出新下载文件。固件脚本使用独立 `vitis_qam` 工作区，生成同目录的 `ris_all_io.elf`、初始化脚本与来源清单。两者均不连接JTAG或编程QSPI。硬件报告见 `reports/qam`，仿真见 `reports/simulation`，本次整链路验证见 [firmware/validation.md](reports/firmware/validation.md)。

## 连接上位机导出包

`scripts/compile_qam_plan.py`验证GUI导出ZIP的SHA-256、所有表边界、容量和时序，输出仅包含寄存器偏移/值的 `upload.bin`、实际速率清单和仿真HEX文件；不含START、不访问硬件，不是TCP/UART指令包。默认要求与源PWM精确相符，现有1 MHz包会拒绝。仅用于明确的改速核线时：

```bash
python3 scripts/compile_qam_plan.py /path/to/host_plan.zip /path/to/new-output-folder \
  --slot-ticks 60 --retime-for-bench
```

输出目录须为新目录，防止覆盖原包。manifest记录源/实际频率、`retimed_for_bench`与 `rf_performance_validated=false`。GUI实时上传直接使用 `ris_qam_transport.py` 生成QAM1快照；C固件位于 `software/`，包含能力报告、顺序/CRC校验、统一STOP及停止后的400位镜像对齐。上述离线MMIO编译器继续用于数字仿真与独立审计。

## Flash启动包

已生成 [20261102_qam/BOOT.bin](export_flash/20261102_qam/BOOT.bin)，包含匹配当前XSA的FSBL、QAM1 BIT和网络ELF。ZC706双并行QSPI类型为`qspi-x8-dual_parallel`，写入偏移`0x0`。镜像大小13,556,752字节，小于32 MiB容量；已完成烧写、两次完整读回和断电启动验收。见 [实板报告](reports/flash/FLASH_REPORT.md)。

完整ZIP、SHA-256清单、分区验证记录和包内说明集中在`export_flash/`；运行时码本和数据仍由GUI上传，不内置到BOOT.bin。

重新打包使用 `python3 scripts/build_qam_boot.py /path/to/new-package-folder`，必须选择不存在的新目录。脚本只生成文件，校验FSBL的PS初始化和双并行QSPI配置，不连接硬件、不执行烧写。
