# RIS 控制与射频接收工程

本仓库包含 20×20、400 路 RIS 控制台，配套 Zynq FPGA/ARM 固件，64QAM/256QAM 码本，FMCOMMS3 射频采集与接收分析程序，以及 FMC 驱动板设计和实验配置。控制台支持全板/单元控制、统一 MT、图案播放、独立 QAM 播放及演示预设；收端提供 PWM 测速、256QAM 验证和三用户验证入口。

本文按当前目录内容整理，更新日期为 **2026-11-17**。硬件状态依据各次验证记录，具体配置、产物和验收范围以对应报告为准。

## 目录索引

```text
RIS/
├── RIS_CTRL/                              电脑端控制程序
│   ├── ris_control_ui_v2/                  主控制台、客户端、预设、预览和测试
│   │   ├── start_gui.sh                    主启动入口
│   │   ├── docs/                          QAM链路、前导码、频率和演示说明
│   │   ├── mappings/、patterns/            FPC—RIS映射、标定配置和图案库
│   │   ├── qam/、examples/                界面配置、MT示例和演示预设
│   │   ├── presets/                       演示槽位的本地持久化快照
│   │   └── tests/、reports/、preview/      自动化测试、验证记录和界面截图
│   ├── legacy_mt_host/                    原版MT控制台
│   ├── fmcomms3_rx_host/                   原有射频采集、下载和频谱上位机
│   └── archive/                           上位机源码历史快照
├── FPGA/                                  RTL、板端固件和硬件工程
│   ├── ris_qam_backend/                    主控制台配套发端工程
│   │   ├── rtl/、constraints/              RTL、引脚和时序约束
│   │   ├── software/、include/             ARM固件、网络协议和寄存器定义
│   │   ├── scripts/、tests/                构建、数字仿真和主机侧验证
│   │   ├── vivado_qam/、vitis_qam/         QAM工作区
│   │   ├── vitis_uplink/                  回传固件/BSP工作区
│   │   ├── export_qam/、export_uplink/     QAM与PL网口回传配套导出
│   │   └── export_flash/、reports/、build/ 启动包、验证记录和构建产物
│   ├── fmcomms3_rx_uplink_20261113/        独立收端工程及快照
│   │   ├── zynq/zc706/fmcomms3_rx/        ZC706收端硬件、固件、host和测试
│   │   ├── baseline/、qspi/               基线及QSPI相关工程副本
│   │   └── staging/                       固件暂存文件
│   ├── zynq/                              既有PZ7035、ZC706控制与接收工程
│   ├── reference/                         PS配置等硬件参考
│   └── reports/legacy/                    历史调试输出
├── QAM_RULES/                             原始码本目录、ZIP和校验清单
│   ├── 256QAM/                            64、100、256 slice码本
│   └── 64QAM/                             16、64、100 slice码本
├── matlab/                                实验MT表、前导码和CONFIG发送预设
├── tools/rx706_capture_linux_20261109/     独立Linux采集下载工具
├── PAPERS/ris_partition_modulation/        分区调制论文、来源和SHA256清单
├── fmc_drive_board/                       FMC驱动板EDA工程、说明与核对脚本
├── NA/                                   保留的PS配置摘要
├── deps/                                 历史Linux桌面动态库副本
├── single_user_image23.json               单用户接收配置样例
└── README.md                              项目入口与目录索引
```

`FPGA/zynq/zc706/ris_ctrl_unit` 为原版控制工程；主控制台的配套板端为 `FPGA/ris_qam_backend`。`RIS_CTRL/fmcomms3_rx_host` 与独立收端工程中的 `host` 分别保留，新增接收分析功能见下文的独立收端入口。

## 环境与启动

本机工具统一放在 `/home/wenhan/SOFTWARE`，每个软件使用独立目录并在其中保存依赖。主控制台默认复用 `/home/wenhan/SOFTWARE/RIS-GUI-V2/runtime`，兼容旧的 `RIS-GUI/runtime`；可用 `RIS_GUI_RUNTIME` 指定兼容运行库。板端构建脚本默认使用该目录下的 Vivado/Vitis 2022.2。

以下命令均从仓库根目录执行。

### RIS 主控制台

```bash
./RIS_CTRL/ris_control_ui_v2/start_gui.sh
```

也可直接进入指定页面：

```bash
./RIS_CTRL/ris_control_ui_v2/start_gui.sh --mt
./RIS_CTRL/ris_control_ui_v2/start_gui.sh --qam
./RIS_CTRL/ris_control_ui_v2/start_gui.sh --qam64
./RIS_CTRL/ris_control_ui_v2/start_gui.sh --demo
```

启动默认只打开界面。选择功能、载入文件、预览或选择停止后，均需点击总“下发指令”按钮才应用输出。`--connect` 可主动建立连接并读取状态，输出仍经总按钮应用。

| 功能 | 使用说明 |
| --- | --- |
| 全板、单元、芯片与图案控制 | 全0/全1、保持、慢速循环、硬件方波、接线检查和图案列表，见[控制台说明](RIS_CTRL/ris_control_ui_v2/README.md)。 |
| 统一400路MT | 支持一次/循环播放、完整波形滚动预览及最多10行前导码；示例见[带延时前导码](RIS_CTRL/ris_control_ui_v2/examples/preamble_mt_with_delay.txt)。 |
| 256QAM与64QAM | 独立配置、码本导入、正式数据上传、K次重复及整帧循环，见[256QAM链路](RIS_CTRL/ris_control_ui_v2/docs/qam256_end_to_end.md)和[64QAM说明](RIS_CTRL/ris_control_ui_v2/docs/qam64_usage.md)。 |
| QPR1独立前缀 | 前导码和四个相偏参考点独立于正式QAM索引及数据，见[前导码](RIS_CTRL/ris_control_ui_v2/docs/qam256_preamble.md)和[相偏参考点](RIS_CTRL/ris_control_ui_v2/docs/qam_phase_compensation.md)。 |
| 演示模式 | 十个槽位加载统一JSON预设；“导出当前配置”保存完整运行参数或表数据，见[操作与恢复规则](RIS_CTRL/ris_control_ui_v2/docs/demo_mode.md)。 |

统一MT和两种QAM的前导码均采用 `(M,T);` 百分比格式，先低电平T%、再高电平M%、其余低电平；最多10行，要求 `M+T≤100%`。循环时每轮重新播放前导码。QAM的四个相偏参考点沿用当前K，正式数据仍保留完整索引空间。带延时前导码的数字与上位机验证见[记录](RIS_CTRL/ris_control_ui_v2/reports/preamble_delay_validation.md)。

QAM输出频率在界面中直接设置，并显示量化后的实际值；slice数决定计时限制，不能仅按调制阶数或码本文件名判断可用频率。规则见[统一PWM频率设置](RIS_CTRL/ris_control_ui_v2/docs/qam_pwm_frequency.md)。码本模型EVM与实际射频接收结果分别记录。

### 采集与接收分析

原有采集上位机与原版MT控制台可分别启动：

```bash
./RIS_CTRL/fmcomms3_rx_host/start_gui.sh
./RIS_CTRL/legacy_mt_host/start_gui.sh
```

独立收端工程包含 PWM测速、256QAM验证、三用户验证及板卡采集子窗口。使用已具备 Tkinter、NumPy 和 Matplotlib 的 Python 环境启动：

```bash
python3 -B FPGA/fmcomms3_rx_uplink_20261113/zynq/zc706/fmcomms3_rx/host/rx706_receiver_gui.py
```

可在命令末尾附加采样 `.bin` 路径。启动后选择功能区、打开采样、加载与实际发送一致的配置，再点击“运行接收”；也可通过“连接板卡 / 采集…”获取新数据。启动时不自动连接、采集或解调。分析依赖清单见收端 `host/requirements-fft.txt`，使用流程见[三功能区说明](FPGA/fmcomms3_rx_uplink_20261113/zynq/zc706/fmcomms3_rx/host/RECEIVER_WORKFLOWS_README.md)及[采集与导入](FPGA/fmcomms3_rx_uplink_20261113/zynq/zc706/fmcomms3_rx/host/RECEIVER_CAPTURE_README.md)。

独立Linux下载包仅依赖Python标准库，有Tk桌面时使用图形界面，否则进入终端菜单：

```bash
bash tools/rx706_capture_linux_20261109/start.sh
bash tools/rx706_capture_linux_20261109/start.sh --cli
```

采集数据使用小端 `int16 I1,Q1,I2,Q2`，配套默认采样率为15.36 MS/s；实际参数以采集元数据为准。保留 `.bin` 与同名 `.bin.json`，下载包含逐块CRC、完整文件SHA256与断点续传。容量、DDR释放及搬运校验见[下载工具说明](tools/rx706_capture_linux_20261109/README.txt)。接收分析需匹配真实发送配置；没有已知净荷参考时BER未测，EVM不能替代误码率验收。

## 网络接口与回传

| 用途 | 板端地址/端口 | 电脑端入口 |
| --- | --- | --- |
| 发端RIS控制，GEM0 / PS Ethernet | `192.168.1.11:7060` TCP | 主控制台 |
| 发端接收回传，GEM1 / PL Ethernet | `192.168.2.11:7061` UDP | 接收RUP1，仅允许来源 `192.168.2.12:7061` |
| 发端回传监视，GEM0 / PS Ethernet | `192.168.1.11:7070` TCP | `monitor_uplink.py`，JSON Lines |
| 收端采集控制/下载 | `192.168.1.10:5001` TCP | 采集GUI或独立下载工具 |
| 收端控制台日志 | `192.168.1.10:5000` TCP | 采集工具控制台 |

PS侧电脑网卡可使用 `192.168.1.20/24`，PL侧测试对端使用 `192.168.2.12/24`；各地址需与实际固件一致。

发端监视入口：

```bash
python3 -B FPGA/ris_qam_backend/scripts/monitor_uplink.py monitor --host 192.168.1.11
```

RUP1包含序号、类型、时间计数、CRC32及最多1024字节净荷。发端将合法数据排队并通过独立7070连接转发。协议、来源过滤、队列容量、断线行为和JSONL保存方式见[UPLINK.md](FPGA/ris_qam_backend/UPLINK.md)。

## 板端构建与配套文件

[发端工程说明](FPGA/ris_qam_backend/README.md)记录RTL结构、上传顺序、寄存器、容量及时序约束；[QPR1说明](FPGA/ris_qam_backend/QPR1.md)记录独立前缀协议。QAM与回传工程分别导出到 `export_qam/` 和 `export_uplink/`，Flash启动包按日期保存在 `export_flash/`。

QAM构建（从仓库根目录执行）：

```bash
cd FPGA/ris_qam_backend
bash scripts/build_qam.sh
bash scripts/build_firmware.sh
```

带PL Ethernet回传功能的构建使用独立工作区与BSP（同样从仓库根目录执行）：

```bash
cd FPGA/ris_qam_backend
bash scripts/build_uplink.sh
bash scripts/build_uplink_firmware.sh
```

两组命令均只构建，不自动下载或烧写。BIT、XSA、ELF、PS初始化文件和BSP应按对应manifest成套使用。码本和正式发送数据由控制台运行时上传。

**版本库与本地产物：** `.gitignore` 忽略部分Vivado/Vitis生成目录及 `*.bit`、`*.elf`、`*.bin` 等文件。本机导出目录或报告中提到的启动包、采样文件不一定包含在Git检出中，使用前需核对实际文件与SHA256清单；缺失的构建产物需由匹配源码和工具链重新生成。

## 验证记录与实板状态

以下是已保存的历史验收事件，不代表所有收发模式均已完成射频验收。

| 范围 | 仓库中的记录 |
| --- | --- |
| QAM1与64QAM历史Flash | 分别完成烧写、两次完整读回及断电启动，见[QAM1报告](FPGA/ris_qam_backend/reports/flash/FLASH_REPORT.md)和[64QAM报告](FPGA/ris_qam_backend/reports/flash_qam64_20261105/FLASH_REPORT.md)。 |
| QPR1，2026-11-10 | 镜像写入及程序内置比较通过，该次未执行额外独立读回和断电网络验收，见[烧写记录](FPGA/ris_qam_backend/reports/flash_qpr1_20261110/FLASH_REPORT.md)。 |
| PL Ethernet回传，2026-11-13 | 发端J18/SGMII千兆链路、18/1024字节回传、CRC与来源拒绝检查通过；对端为Linux网卡模拟收端，见[JTAG实板记录](FPGA/ris_qam_backend/reports/pl_eth_sgmii_20261113/board_test/result.json)。 |
| 回传镜像Flash，2026-11-13 | 烧写、直接全字节比较、QSPI冷启动与网络状态检查通过，未执行独立 `program_flash verify`；记录明确未做真实双板及射频测试，见[烧写及冷启动记录](FPGA/ris_qam_backend/reports/flash_uplink_20261113/hardware_programming.json)。 |
| 演示模式与延时前导码 | 上位机、Tk/TCP/C模型及数字波形验证范围分别见[演示验证](RIS_CTRL/ris_control_ui_v2/reports/demo_mode/validation.md)和[延时前导码验证](RIS_CTRL/ris_control_ui_v2/reports/preamble_delay_validation.md)。 |

发端数字仿真与回传离线测试可从 `FPGA/ris_qam_backend` 运行：

```bash
bash tests/run_sim.sh icarus
bash tests/run_qam64_sim.sh
bash tests/run_prefix_sim.sh
python3 -B tests/run_uplink_tests.py
python3 -B tests/run_pl_eth_board_tests.py
python3 -B tests/run_uplink_bsp_tests.py
```

脚本需要各自对应的本地仿真器、C编译器或Xilinx工具链。上位机测试在 `RIS_CTRL/ris_control_ui_v2/tests/`；独立收端测试在其 `zynq/zc706/fmcomms3_rx/tests/`。含Tk窗口的测试需要可用图形显示。历史报告中的“通过”仅对应报告列出的配置和范围。

## 实验配置与硬件资料

- `matlab/CONFIG/` 保存统一发送预设，包括256QAM 10K/20K、PWM与三用户配置，可用于演示预设加载；具体频率和表数据以JSON内容为准。
- `matlab/PRE_10.txt`、`PRE_4.txt` 保存前导码MT表，`MT_3users_60symbols.txt`、`mt_test*.txt` 保存实验MT序列。目录名 `matlab` 下的这些文件也供控制台使用。
- `single_user_image23.json` 为单用户接收配置；发送预设、接收参数、FPC映射与码本各有独立格式，按相应功能入口加载。
- `QAM_RULES/` 保存不同阶数和slice数的原始码本与校验清单；FPC接线映射单独位于主控制台 `mappings/`。
- [分区调制论文](PAPERS/ris_partition_modulation/README.md)附来源、版本及文件校验值。
- `fmc_drive_board/` 保存嘉立创EDA工程、备份、核对脚本和设计说明，见[外部12V电源](fmc_drive_board/EXT_12V_design.md)与[RIS 1.5V电源](fmc_drive_board/RIS_1V5_design.md)。

各 `reports/` 目录用于追溯构建、仿真、烧写与采集验证；第三方代码的许可及来源随代码保留。历史日志和部分副本说明中的绝对路径表示当时的环境，实际启动以本页入口和当前脚本为准。
