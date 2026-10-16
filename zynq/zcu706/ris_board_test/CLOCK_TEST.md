# FMC_LPC 时钟与 DATA 测试工程

顶层为 `ris_clock_test`，RTL 和 XDC 已加入 `ris_board_test.xpr`。

- RTL：`ris_board_test.srcs/sources_1/new/ris_clock_test.v`
- XDC：`ris_board_test.srcs/constrs_1/new/ris_clock_test_lpc.xdc`
- 输入：ZC706 板载 200 MHz SYSCLK（H9/G9），经 IBUFDS、1 个 BUFG。
- 输出：20 个独立 ODDR，全部输出同源 200 MHz 时钟，LVCMOS25。
- DATA：新增 DATA_U01～DATA_U50，按原理图原位置绑定；50 位计数器产生测试数据。
- 全部约束：20 CLK + 50 DATA + 2 SYSCLK，共 72 个端口；OE/MR 尚未加入。
- 第 1 组改为 G36/G37（Y30/AA30）；第 3 组改为 H37/H38（Y26/Y27）；其余保持 LPC 原映射。

本设计用于验证 FPGA 输出引脚和布线，不包含子板 595 的移位/锁存事务协议，不代表子板能以 200 MHz 工作。未下载硬件。

从 Vivado 打开 `ris_board_test.xpr`，可在 Sources 中查看顶层和约束，在 Design Runs 中查看 synth_1/impl_1 的结果。若 GUI 在文件更新前已打开工程，重新打开工程以加载磁盘上的更新。

批处理复现：在 `clock_validation` 中执行：

```bash
/home/yyz/vivado2020.2/main/Vivado/2020.2/bin/vivado -mode batch -source run_project.tcl -log project_run.log -journal project_run.jou
```

最终检查报告：`clock_validation/project_run/`；bitstream：`ris_board_test.runs/impl_1/ris_clock_test.bit`。

子板改线和已发现的 VADJ 引脚错误详见 `clock_validation/LPC_CLOCK_REWIRE.md`。未改线的子板不能直接使用这套改后约束。原 xpr 备份保存在 `clock_validation/ris_board_test_before_clock_test.xpr`。
