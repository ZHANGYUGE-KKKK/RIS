# RFMC6000 7035 参考配置（原文件）

来源：`/home/yyz/ALLdoc/RFMC6000/3 FPGA测试例程/adaloop_deepreads.zip`
内部目录：`adaloop_deepreads/vitis_7035/ad9361_app/src/`

`src/` 中的 24 个文件保持原始字节，未加入当前应用的构建。
`manifest.json` 记录各文件 SHA-256，已逐文件与压缩包校验一致。

## 配置位置

- `src/radio_set.h:13`：完整 `AD9361_InitParam default_init_param`。
- `src/radio_set.h:240`：RX/TX FIR 预设，4 倍/128 taps，2 倍/128、96、64 taps。
- `src/ad9361_config.c:30`：按采样率选择预设 FIR，设置采样率并使能滤波器。
- `src/ad9361_config.c:63`：应用频点、带宽、手动增益和 TX 衰减。
- `src/main.c:64`：初始化之后应用的运行参数。
- `src/spi_ctrl.c:9`：CDCM6208 40 MHz 参考时钟寄存器配置。

## 两阶段参数，不要混淆

| 参数 | radio_set.h 初始化值 | main.c 随后配置值 |
| --- | --- | --- |
| 参考时钟 | 40 MHz | 40 MHz（CDCM6208 配置） |
| RX LO | 2.4 GHz | 200 MHz |
| TX LO | 2.4 GHz | 5997 MHz |
| 采样率 | 40 MSPS | 61.44 MSPS |
| RX/TX 带宽 | 20 MHz | 30.72 MHz |
| RX 增益 | MGC 模式 | 两通道 5 dB |
| TX 衰减 | 20 dB | 0 dB |

61.44 MSPS 时，`ad9361_set_sample()` 选择 64 taps、RX 抽取 2 / TX 插值 2。
`radio_set.h` 中 FIR 的 `*_path_clks`/`*_bandwidth` 是零，示例由驱动动态设置
采样率和带宽；这些预设并非独立的、无需驱动即可下发的全芯片寄存器表。

## 与当前工程对齐时的重点

- 当前采集 RTL 为双 RX、LVDS DDR；模板也是 2R2T、FDD、LVDS。
- `rx_frame_pulse_mode_enable=1` 应保持：UG-671 对 0x010[D3] 的说明为
  1 时 RX_FRAME 以 50% 占空比翻转，0 时首个有效样本之后保持高电平。
  当前 RTL 需要重复翻转的帧，不能改为 0。
- 参考先用 SPI1 初始化 CDCM6208，等待锁定，再用 SPI0 初始化 AD9361。
  当前顶层只引出 AD9361 SPI0 和 RESETB，需要补齐时钟控制或确认现有参考时钟。
- GPIO 编号使用当前 XSA：RESETB 为 PS GPIO 54（EMIO[0]），不要直接沿用
  参考 `parameters.h` 的 0..9 编号。
- 原 main.c 含原工程专用 AXI Lite、DDS、XADC 和 TX 路径操作，移植时按当前
  接收采集设计选取需要的初始化步骤。
- 官方核心 `ad9361.c`/`ad9361_api.c` 与当前在线检查驱动同名，移植要处理命名
  和 SPI/GPIO 适配。当前应用源码、bitstream 和运行参数均未因此次查找而改变。

## 压缩包内的其他版本

三版 `radio_set.h` 和 `ad9361_config.c` 字节完全相同；主要区别在 main.c：

| 版本 | RX LO | TX LO | 采样率 | 带宽 | RX 增益 | TX 衰减 |
| --- | --- | --- | --- | --- | --- | --- |
| pldma_test.sdk/sdr_test | 2500 MHz | 2500 MHz | 61.44 MSPS | 30.72 MHz | 5 dB | 20 dB |
| vitis/fmc9361_app | 200 MHz | 200 MHz | 61.44 MSPS | 30.72 MHz | 5 dB | 20 dB |
| vitis_7035/ad9361_app | 200 MHz | 5997 MHz | 61.44 MSPS | 30.72 MHz | 5 dB | 0 dB |

寄存器手册副本：[UG-671](docs/AD9361_Register_Map_Reference_Manual_UG-671.pdf)，RX_FRAME 说明见 0x010[D3]。
