# AD-FMCOMMS3 Rev.A 与 ZC706 FMC HPC 兼容性核对

结论：硬件具备适配HPC的条件，但ADI标准FMCOMMS2/3/4 ZC706工程连接LPC J5。HPC J37必须使用对应HPC引脚、时钟/电气约束和平台配置，不能直接运行标准LPC镜像。当前PZ7035 xc7z035工程的bit/XSA也不能用于ZC706 xc7z045。

依据：用户FMCOMMS3原理图第3、4页；AMD UG954 v1.8第67至74页FMC连接表、第81至82页VADJ控制与第1-28表LED。UG954官方PDF已下载至/tmp/zc706_ug954.pdf用于核对。网页来源：
- https://analogdevicesinc.github.io/hdl/projects/fmcomms2/index.html
- https://docs.amd.com/api/khub/documents/m4fPXowvxKd5JZRfe046WQ/content
- https://ez.analog.com/linux-software-drivers/f/q-a/90610/fmcomms3-and-zc706

FMCOMMS3使用LPC针位C/D/G/H；ZC706 HPC中所需LA、时钟、SPI、RESETB和电源连接存在。核对的关键HPC映射（非完整可用XDC）：

| 功能 | FMC针位 | ZC706 HPC FPGA球位 |
|---|---|---|
| DATA_CLK P/N | G6/G7 | AF20/AG20 |
| RX_FRAME P/N | D8/D9 | AG21/AH21 |
| SPI MOSI/MISO | C26/C27 | V28/V29 |
| SPI CLK/CS | D27/D26 | T28/R28 |
| RESETB | H31 | P30 |
| PG_C2M | D1 | PWRCTL1_FMC_PG_C2M（亦到AB20） |

对照，ZC706 LPC的DATA_CLK G6/G7为AE13/AF13，与HPC不同。必须同时适配全部数据lane、TX接口、极性和软件GPIO，不只改时钟两个球位。

ZC706 VADJ默认2.5V，J18默认短接使上电时启用VADJ。可通过TI电源控制器/端口扩展器调整，机制与PZ7035硬件选电阻不同。VADJ也供相关FPGA VCCO，软件/约束须匹配实际电压；不可照抄PZ7035的1.8V单端约束。

子板DS21还是本地1P8V电源LED。子板3P3V经U301产生1P8V，EN由PG_C2M控制。因此ZC706需检查母板DS23（FMC power good）、J18状态、FMC3P3V、PG_C2M及子板1P8V。DS21不亮不等于HPC不兼容；未实测电压，尚未定位具体电源故障。不要混淆ZC706主板DS21（DDR电源指示）与子板DS21。

本轮只读核对，未连接/编程ZC706，未改当前035工程。若要用官方工程做对照，优先断电后把FMCOMMS3插到ZC706 LPC J5，并采用匹配的官方HDL/软件。
