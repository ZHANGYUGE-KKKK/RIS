# 64QAM接入验证（2026-11-05）

主控制台新增“MT时域控制 → 400路独立 / 64QAM”，与统一MT/256QAM并列。采用用户指定的 `QAM_RULES/64QAM/ris_64qam_64slice_codebook`，64个符号、IIIQQQ Gray映射、64片、160 kHz、默认K=1。源文件只读；每字节一个00–3F符号ID，越界拒绝、不截断高位。

## 时序与兼容

AXI100 MHz、引擎300 MHz、SHCP100 MHz均保持不变。原256QAM命令、CRC、200 ns最小片长及播放结构保留。新增64模式仍复用字典、事件表、预取、K/整帧循环和400位停止保持。

每个PWM周期1875 tick=6.25 µs，64个源片按最近tick量化为45个29-tick片和19个30-tick片。边沿误差≤1.667 ns；PWM周期边界、前导码、K重复和帧边界无累计漂移。新模式最短事件29 tick，STCP高至少2 tick；实物器件电气指标与空口性能仍需板上确认。

源码本的1.0673%均衡EVM为源模型值，不能代替本次量化或实测EVM。此次未连接实际板卡，未下载、未烧写，也未做RF测量。

## 已完成检查

- QAM/GUI/真实C协议完整回归43项通过；最终64QAM核心6项、GUI/TCP3项通过。
- 原256QAM码本18项、离线编译8项、频率4项通过。
- 全64个符号每个源片的400位空间图案与独立映射 oracle 一致；每个周期严格1875 tick。
- 离线编译与实时上传表在原速和显式低速核线下逐字节一致，均覆盖前导码及K。
- 原版Vivado ODDR数字模型：64符号+10行前导码、跨帧循环、全部锁存间隔、29-tick最密更新、SHCP高低5 ns、DS建立、STCP脉宽、STOP和短事件拒绝通过。
- RTL回归：原256QAM全部00–FF共26103个事件、统一MT、FAST1/3/5 MHz、普通50片595、FAST开/关两套AXI整链路通过。
- Vivado综合/布局/布线/物理优化通过：WNS +0.031 ns，WHS +0.077 ns，TNS/THS为0，DRC无Error/Critical Warning。LUT6.47%、FF4.15%。初次布线的负余量经物理优化消除。
- ARM网络ELF构建通过，源码/头文件/精确BIT-XSA/PS初始化/ELF来源及SHA-256均通过配套核验。
- 新BOOT.bin包含匹配FSBL、BIT、ELF，大小13,556,752字节；分区校验、数据匹配、ZIP与SHA清单通过，未烧写。

## 交付

- `FPGA/ris_qam_backend/export_qam/`：配套BIT、XSA、ELF、初始化及来源清单。
- `FPGA/ris_qam_backend/export_flash/20261105_qam64/BOOT.bin`：新Flash启动镜像。
- `FPGA/ris_qam_backend/export_flash/RIS_ZC706_QAM_QSPI_20261105_qam64.zip`：配套包。
- `RIS_CTRL/ris_control_ui_v2/docs/qam64_usage.md`：操作、数据格式、边沿量化与新增ABI。
- `RIS_CTRL/ris_control_ui_v2/preview/17_qam64_preview.png`、`18_qam64_parameters.png`：真实离线Tk界面截图。

可复现入口：`bash tests/run_qam64_sim.sh`、`bash tests/run_sim.sh icarus`、`python3 tests/check_qam64_offline.py`、上位机 `./run_tests.sh -p 'test_qam*.py'`。最终源码、码本、日志和产物SHA见同目录 `validation.json`。早期首次回归中的静态状态标题问题已修正，并通过最终整套回归。
