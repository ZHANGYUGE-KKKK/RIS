RIS 控制台 v2 启动入口

启动脚本：/home/wenhan/SOFTWARE/RIS-GUI-V2/start-ris-gui.sh
图形入口：/home/wenhan/SOFTWARE/RIS-GUI-V2/ris-gui-v2.desktop
程序源码：/home/wenhan/PROJECTS/RIS/ris_control_ui_v2
使用说明：/home/wenhan/PROJECTS/RIS/ris_control_ui_v2/README.md

默认不连接板卡。连接后仍需点击右上角总下发按钮应用配置。
保留并支持 --mt、--patterns、--mapping、--connect 等参数。

runtime/ 和 packages/ 从已有 RIS-GUI 复制，属于本入口的独立依赖。
没有更改旧版 RIS-GUI，没有联网下载或修改系统安装、环境配置。
入口及新增依赖全部位于本目录；删除本目录即可移除它们。
源码和映射、图案等项目数据继续保存在上述项目副本中。
