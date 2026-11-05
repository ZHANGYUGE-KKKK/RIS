2026-10-20 DMA/DDR 软件诊断交付

用户操作入口：项目根目录 DMA_DEBUG_GUIDE.txt。
默认射频配置仍为 CONFIG2P4，未改变任何 AD9361 配置、RTL、BIT或XSA。
本次未连接、复位、编程或测试实际板卡；由用户下载并重新采集。

新增能力
  全部BD在准备后、提交后各做一次读回检查，仍在ARM之前完成。
  完成的BD使用同一次volatile原始快照解码，记录完整状态和实际长度。
  保留出错BD、重复读回结果和DMA寄存器，避免复位抹掉原始现场。
  在DMA完成、仅DMA复位、完整PL采集复位三个阶段执行有界DDR窗口检查。
  下载时检查实际发出的IQ字，仍逐字保存原始BIN，不自动修补或掩盖异常。
  UART/TCP控制台d打印保存的报告；DEBUG命令返回窗口详情。
  新版Python下载会保存capture_final和debug到同名JSON。
  本版仍是32 KiB/BD；单BD大包测试需后续RTL配合，本次没有修改TLAST周期。

重要解释
  旧bd_status=0x8C000000是驱动掩码后的状态，不等于实际长度为0。
  本版debug_bd_raw_status和debug_bd_actual保留原始长度字段。
  窗口检查是抽样；零掩码不证明全文件有效。
  READ非法字统计按请求累计，重传或重复下载会重复计数。
  本版只增加定位证据，尚未声称修复FIFO、DMA、DDR或读出路径的根因。

构建与验证
  application_build.log：ARM交叉编译、链接、导出通过，没有编译警告或错误。
  network_tests.log：ASan/UBSan C测试、12项实际TCP协议/下载测试、9项Tk GUI测试通过。
  network_tests_final.log：最终打印改动后的C及12项TCP回归通过。
  network_915_tests.log：CONFIG915的C测试和12项TCP兼容性检查通过。
  configuration_tests.log：5项配置来源/时钟/兼容性检查通过。
  spectrum_tests.log：10项原始IQ频谱测试通过。
  C故障注入覆盖复位阶段数据改变、原始非法值不被修补、DEBUG响应容量、
  BD实际长度缺失、SOF/EOF、Buffer、NEXT和ID错误的分项识别。
  native测试使用模拟DMA；只有交叉编译使用真实BSP/驱动，不代替板级验证。
  migration_integrity.log：原始91个迁移来源和硬件连接/参数保持一致。
  release.sha256.json：交付程序、53个应用源文件和支持文件哈希。
  其中21项受保护RF/硬件文件与修改前完全相同。

产物
  export/key_ctrlll_dma_debug.elf
  export/key_ctrlll.elf
  export/key_ctrlll_2p4.elf
  vitis_code/key_ctrlll/Debug/key_ctrlll.elf
  四个ELF字节一致，SHA-256：
    731685c6def7e2b75ec8874677627c2b59af49f29652fbef40f204f6a99f2bd2

追溯
  before/及before.sha256.json保存修改前应用源码、ELF、相关支持文件和清单。
  changes.patch提供修改前后的源码差异，包含四个新增驱动文件。
  通过 ./build_rx_network.sh 可重编译当前默认2.4 GHz程序。
