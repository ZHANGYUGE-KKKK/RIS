CONFIG2P4 软件接入与编译记录
日期：2026-10-20

交付
  export/key_ctrlll_2p4.elf：本次2.4 GHz发布快照。
  export/key_ctrlll.elf：当前默认下载文件，内容与上述快照一致。
  vitis_code/key_ctrlll/Debug/key_ctrlll.elf：Vitis应用编译结果，内容相同。
  ELF SHA256：f8486b0b8a3d408faf35b09df8694982cffc3373f99f0abe1e2b98d0e037cac6
  人工上板说明：项目根目录 CONFIG2P4_RX_GUIDE.txt。

实现
  保留原config915_data.h及915初始化入口；共享脚本执行器支持两个配置。
  新增config2p4_data.h，由config/config2p4逐条转换，共2568条操作。
  build_rx_network.sh增加生成步骤，未改变原始GUI导出脚本。
  rf_profile.h默认CONFIG2P4：RX/TX LO=2400 MHz，Fs=15.36 MSPS。
  保留晶体/DCXO、009适配、0A3掩码写、FDD收尾、原数字接口与采集流程。
  CONFIG2P4常态BIST=00/00/00；PN自检临时启用后恢复原值。
  CONFIG915仍保留原TX BIST=53/00/30。
  外部测试提示随配置选择2401/2402或916/917 MHz。
  导出JSON增加当前profile，并使用无符号2400000000 Hz记录LO。
  Python断点续传把LO纳入同一采集身份检查，避免跨频点追加旧文件。

验证通过
  ARM应用编译与链接，无warning/error；application_build.log。
  5项脚本转换/时钟解码/兼容性检查；configuration_tests.log。
  两种profile各12项真实C调度器到TCP/Python的导出与续传测试。
  两种profile均通过原生ASan/UBSan、内存映射和采集所有权检查。
  默认2.4 GHz配置通过9项Tk GUI回归检查；network_gui_tests.log。
  9项FFT检查，包含2.4 GHz元数据与基带频率；spectrum_tests.log。
  915选择通过三个受影响C源文件的ARM语法编译；915_arm_compile.log。
  原始软件快照、BD/AXI连接与地址、硬件参数完整性检查；migration_integrity.log。
  1578个本次基线文件哈希保持不变，含全部已记录PL/XDC/XSA、原始配置和底层驱动。

备份与审计
  before.sha256.json：本次修改前的基线。
  before/：本次修改前的源文件、旧915 ELF、指南及发布清单。
  verification.json：配置、ELF校验和、验证范围。
  release.sha256.json：当前完整应用、支持文件及配置/硬件发布校验和。
  公共应用源清单与export/manifest.json已同步更新；旧版本清单保留在before/。

未执行的操作
  没有连接、复位或下载板卡，没有改动PL/XDC或重新生成XSA。
  实物PLL锁定、PN、时钟/FRAME稳定与外部RF接收仍待用户上板验证。
