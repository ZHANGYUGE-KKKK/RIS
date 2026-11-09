# RIS 工程目录

本工程按上位机、FPGA/板端、QAM码本和驱动板硬件分类。软件工具及安装依赖位于 `/home/wenhan/SOFTWARE`；程序从项目内部启动。

## 文件结构

```text
RIS/
├── RIS_CTRL/                         上位机
│   ├── ris_control_ui_v2/             主控制台、Python客户端和上位机测试
│   │   ├── start_gui.sh               启动入口
│   │   ├── docs/                     控制台、QAM链路及前导码说明
│   │   ├── mappings/                 FPC—RIS接线映射和标定配置
│   │   ├── patterns/                 图案库
│   │   ├── qam/                      QAM界面配置
│   │   ├── matlab/、examples/         MT表及配置示例
│   │   ├── reports/                  上位机验证日志
│   │   └── tests/                    上位机与协议联调测试
│   ├── legacy_mt_host/                原版MT控制台及其测试、示例
│   ├── fmcomms3_rx_host/              射频采集上位机、频谱分析和采集文件
│   └── archive/                      上位机源码历史快照
├── FPGA/                             RTL、板端固件和硬件工程
│   ├── ris_qam_backend/               与主控制台配套的QAM1板端工程
│   │   ├── rtl/、constraints/         RTL和引脚/时序约束
│   │   ├── software/、include/        ARM固件、TCP协议和寄存器定义
│   │   ├── scripts/、tests/           构建、核验和数字仿真入口
│   │   ├── vivado_qam/、vitis_qam/    Vivado/Vitis工作区
│   │   ├── export_qam/                配套BIT、XSA、ELF和初始化文件
│   │   ├── export_flash/              Flash启动镜像及配套包
│   │   └── reports/、build/           验证记录与构建产物
│   ├── zynq/                         既有PZ7035、ZC706控制与射频接收工程
│   ├── reference/                    PS配置等硬件参考
│   └── reports/legacy/               根目录原有的调试输出
├── QAM_RULES/                        QAM映射规则与码本
│   ├── 256QAM/                       256QAM源码本目录及ZIP
│   └── 64QAM/                        64QAM码本ZIP
├── fmc_drive_board/                  FMC驱动板EDA工程、设计说明、核对脚本和备份
├── deps/                             历史Linux桌面动态库副本
├── .gitignore                       生成文件忽略规则
└── README.md                        本目录索引
```

## 上位机入口

从工程根目录执行：

```bash
./RIS_CTRL/ris_control_ui_v2/start_gui.sh
```

直接进入QAM页面：

```bash
./RIS_CTRL/ris_control_ui_v2/start_gui.sh --qam
```

原版MT和射频采集上位机入口分别为 `RIS_CTRL/legacy_mt_host/start_gui.sh`、`RIS_CTRL/fmcomms3_rx_host/start_gui.sh`。

启动脚本按自身位置定位源码，沿用 `/home/wenhan/SOFTWARE/RIS-GUI-V2/runtime` 中的运行库；可通过 `RIS_GUI_RUNTIME` 指定兼容运行库。启动默认不连接板卡，输出配置由界面总“下发指令”按钮应用。

[控制台说明](RIS_CTRL/ris_control_ui_v2/README.md) · [QAM链路](RIS_CTRL/ris_control_ui_v2/docs/qam256_end_to_end.md) · [前导码](RIS_CTRL/ris_control_ui_v2/docs/qam256_preamble.md)

## 分类边界

- `RIS_CTRL` 保存电脑端程序和本地配置；板端C固件、RTL、Vivado/Vitis工程及烧写文件归入 `FPGA`。
- `QAM_RULES` 保存码本原始数据，上位机直接读取，不再维护内置重复ZIP。QAM码本与FPC接线映射用途不同；后者保存在控制台的 `mappings` 中。
- `FPGA/ris_qam_backend` 是主控制台配套板端工程。`FPGA/zynq/zc706/ris_ctrl_unit` 保存原版控制工程，原上位机已分离到 `RIS_CTRL/legacy_mt_host`。
- 各部分通过码本文件、网络协议或配套导出文件衔接。跨端联调测试引用另一部分的明确路径，不复制其源码。
- `fmc_drive_board` 保存实体驱动板设计。`NA/ps7_summary.html` 已归入 `FPGA/reference`；原零散时序和仿真输出已归入 `FPGA/reports/legacy`。
- `deps` 内是托盘、通知及密钥环相关的历史桌面库；主控制台运行环境由 `runtime_env.sh` 配置。

[FPGA工程说明](FPGA/ris_qam_backend/README.md) · [驱动板电源设计](fmc_drive_board/EXT_12V_design.md)

## 配套文件与记录

板端导出文件集中在 `FPGA/ris_qam_backend/export_qam`，Flash包集中在 `export_flash`。BIT、XSA、ELF、PS初始化文件按配套清单使用。目录整理不重建或烧写硬件。

`reports` 中保留与具体构建、测试及烧写产物对应的记录；第三方源码来源和许可说明随对应代码保留。归档日志中的绝对路径表示记录产生时的位置。

64QAM已作为独立控制类型接入主控制台（与256QAM并列）；默认码本为 `QAM_RULES/64QAM/ris_64qam_64slice_codebook`，入口 `./RIS_CTRL/ris_control_ui_v2/start_gui.sh --qam64`。操作、时序及配套文件要求见 [64QAM说明](RIS_CTRL/ris_control_ui_v2/docs/qam64_usage.md)。

2026-11-09：QAM已同步增加QPR1独立前导码与相偏描述，解除前缀对256项QAM索引的占用。配套[Flash包](FPGA/ris_qam_backend/export_flash/RIS_ZC706_QAM_QSPI_20261109_qpr1.zip)已离线生成并校验，尚未烧写；见[验证记录](FPGA/ris_qam_backend/reports/prefix/validation.md)。
