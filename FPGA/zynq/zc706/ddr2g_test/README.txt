ZC706 独立 2GB PL DDR 自检工程
================================
用途：使用另一根 2GB SO-DIMM，独立检查 MIG/PL DDR 的读写稳定性。
本工程与 fmcomms3_rx 分开，不修改接收工程或 AD9361 配置。
仅离线准备；是否已上板实测，以 reports/verification.json 和后续板测记录为准。

目标内存
--------
实物：Micron MT16JSF25664HZ-1G4F1，2GB（2 GiB），2Rx8，x64，1.5V。
DDR3-1333，CK 666.667 MHz，CL9、CWL7；每 Rank 1 GiB。
每颗 1Gb x8，Row=14，Column=10，Bank=3；两个 Rank，而不是把 Row 改成15。
Vivado 2020.2 的器件库没有旧 JSF 型号，使用相同组织/速度的
MT16JTF25664HZ-1G4 控制器配置，配套 XML 保留在 constraints/ddr2g_mig.prj。
Rank 1 的 CS、CKE、ODT 及第二对 CK 均连接并约束，非仅扩大软件地址范围。
地址镜像当前关闭；未读取实物 SPD。离线生成不能替代实物校准和全容量检查。

时钟
----
板载 H9/G9 200 MHz -> Clocking Wizard 166.666667 MHz -> MIG。
MIG 内部 PLL M=8、D=1、OUT0=2，DDR CK=666.666667 MHz；UI=166.666667 MHz。
IODELAY 参考时钟单独使用板载 200 MHz。
MIG 内部为数据延时单元生成400 MHz参考。其保留的200 MHz就绪控制器
没有对应数据延时单元，构建脚本仅去掉该空分组；保留控制器及RDY连线，
64个实际数据延时单元仍使用MIG原400 MHz分组，不修改数据采样延时。
MIG XML 对166.666 MHz的表示按其GUI列表取值，生成 RTL 的 CLKIN_PERIOD=6000ps。
使用 Clocking Wizard 是为满足 MIG 的输入时钟组合，不更改原1GB工程的频率。

数据路径和范围
--------------
PL BIST AXI Master -> MIG -> PL SO-DIMM；PS GP0 只访问控制/状态 GPIO。
BIST 使用512位数据、64字节对齐、完整写掩码、单拍、单笔在途事务。
每项测试先写完全部指定区域，再读回逐个32位字比较。
完整本地地址 0x00000000..0x7FFFFFFF，共2 GiB。
此地址是 PL 主设备的本地地址，不是 PS 的平铺地址。
PS 程序、栈、堆和 BSP 均放在 PS DDR；测试不会写 PS 程序区。
本工程不初始化 AD9361、DMA 或网口；只用 JTAG 下载和 UART1 115200 8N1。
测试图案：全0、全1、AA55AA55、字节地址 XOR 6D3A92C7、前者取反。
地址图案可检查两个地址半区混叠；均匀常数图案单独通过不能排除混叠。

文件和下载
----------
Vivado: vivado/ddr2g_test.xpr
Vitis:  vitis_workspace （独立工作区，进入后打开 ddr2g_test 应用）
若只显示主界面：关闭此测试工作区，在XSCT执行 scripts/import_workspace.tcl，
再打开同一工作区。该脚本注册现有平台/应用，不重建或烧写硬件。
交付:   export/ddr2g_test.bit / ddr2g_test.xsa / ddr2g_test.elf / ps7_init.tcl
手动下载并运行：
  cd /home/yyz/work/RIS/zynq/zc706/ddr2g_test
  /home/yyz/vivado2020.2/main/Vitis/2020.2/bin/xsct scripts/program.tcl run
省略 run 时，仅下载并停在 ELF 入口。
脚本要求仅一个 XC7Z045 JTAG 目标，避免把另一块706误烧写。
更换内存条应断电完成，再下载本工程。不会写入板卡启动 Flash。

串口控制
--------
上电并运行后不会自动写内存。CuteCom ASCII 单字符发送即可，回车会被忽略。
建议顺序：s -> 0 -> 1 -> f -> a。
  s  查看 ready/calib/mmcm/ui_reset/busy/done 和错误信息。
  0  0x00000000..0x007FFFFF，低地址8 MiB，五种图案。
  1  0x40000000..0x407FFFFF，高地址8 MiB，五种图案。
  f  完整2 GiB，地址图案；检查全容量/地址混叠。
  a  完整2 GiB，五种图案；每种都先全写后全读。
  h  显示菜单。
运行中每秒打印进度；测试执行期间不要排队发送多个命令。
f 是完整范围写一遍再读一遍，a 是五轮，不是DDR带宽跑分。
PASS 需要完整测试结束、错误字数为0、无AXI响应错误。异常/超时不能视为通过。
若事务卡住，程序打印状态后保留现场，不在AXI事务中强制复位。
首个错误 offset 是相对于 PL DDR 的本地字节地址，记录 expected/actual/error_words。
0/1 两个短检查都通过后仍需 f，才检查完整容量和半区地址混叠。
各地址半区是否严格对应同一物理Rank取决于MIG地址映射；以全容量覆盖为依据。

复现构建
--------
完整离线构建：bash scripts/build_all.sh（不会连接/下载板卡）。
Vivado 2020.2：
  vivado -mode batch -source scripts/create_project.tcl
  vivado -mode batch -source scripts/simulate.tcl
  vivado -mode batch -source scripts/build_hardware.tcl
Vitis 2020.2：
  bash scripts/build_software.sh
  xsct scripts/prepare_vitis.tcl
打包核查：
  python3 scripts/verify_release.py
脚本中的本机工具路径与当前安装目录一致。

判读范围
--------
仿真检验的是 BIST 协议/图案/错误报告，未仿真实物DRAM信号完整性。
CDC 中两条状态标记0xA的复位后常量复制路径有明确豁免；不豁免错误数、
地址、DONE、命令等有效业务路径。400 MHz数据延时组保持原MIG实现。
DRC REQP-1709 来自原生MIG内部PLL的BUFH/BUFG不同负载；保持厂商时钟结构，
建立、保持和脉宽时序均须通过。此警告不是被降级/屏蔽后伪装成无警告。
本工程的内存条、速率及访存路径与原接收工程不同。
2GB BIST 通过说明此工程在该条内存上通过测试，不能单凭这一结果判定原1GB条损坏，
也不能据此宣布原接收工程的数据链路已修复。后续再用共同条件做对照定位。

参考
----
Micron JSF 双Rank SO-DIMM 数据手册（厂家文档镜像）：
https://datasheet.octopart.com/MT16JSF25664HZ-1G4F1-Micron-datasheet-11800864.pdf
AMD ZC706 UG954：
https://docs.amd.com/api/khub/documents/m4fPXowvxKd5JZRfe046WQ/content
Vivado本机配置库：
/home/yyz/vivado2020.2/main/Vivado/2020.2/data/ip/xilinx/mig_7series_v4_2/data/mem_tlib/ddr3_sdram/sodimms/mt16jxf25664hz-1g4.xml
