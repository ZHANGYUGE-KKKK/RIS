# RFMC6000 接收对照模型

`axi_ad9361_dev_if_idelay.v` 原样取自本地参考压缩包：

`/home/yyz/ALLdoc/RFMC6000/3 FPGA测试例程/adaloop_deepreads.zip`

包内路径：
`adaloop_deepreads/pldma_test.srcs/sources_1/new/axi_ad9361_dev_if_idelay.v`。

保留原 ADI 版权及许可。仅供测试台对照使用，不加入硬件工程。
测试台将同一组物理 LVDS 数据、FRAME 和 DATA_CLK 同时送入参考接口与项目
接收器，逐组比较双 RX 的完整 I/Q；项目的 AXIS 输出另由连续序号和极值数据
检查，覆盖异步 FIFO、反压、TLAST、复位及故障停止。
