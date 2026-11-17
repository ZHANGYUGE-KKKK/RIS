# 发端 PL Ethernet 回传接收与 PS Ethernet 监视

本实现只修改发端 `ris_qam_backend`。收端未来通过 PL Ethernet 发送回传数据；发端通过 GEM1 接收，并通过 GEM0 向上位机提供独立监视流。发端已通过实板测试，收端由 Linux 网卡模拟。双板联调待收端就绪。

## 接口与数据路径

| 用途 | 发端接口 | 发端地址 | 对端 |
| --- | --- | --- | --- |
| 原 RIS 控制 | GEM0 / PS Ethernet | `192.168.1.11:7060` TCP | 现有 RIS GUI |
| 新回传入口 | GEM1 / PL Ethernet | `192.168.2.11:7061` UDP | 仅 `192.168.2.12:7061` |
| 新上位机监视 | GEM0 / PS Ethernet | `192.168.1.11:7070` TCP | 独立 Python 监视脚本 |

两个网口均使用 `/24` 掩码。默认路由接口保持 GEM0。GEM0 MAC 保持 `02:0a:35:07:06:02`，GEM1 使用 `02:0a:35:07:06:03`。地址常量位于 `software/network/ris_network.h` 和 `software/network/ris_uplink.h`。

`7060` 命令与 `7070` 监视监听器均绑定 GEM0 的 IP 和 netif。UDP 入口绑定 GEM1，并再次核对实际接收 netif、目标 IP、源 IP 和源端口。回传字节始终作为数据处理，不进入 `ris_protocol_execute()`。监视连接只允许接收数据：向该连接发送任何字节会被断开。

现有 GUI 可继续使用 `7060`，同时运行一个 `7070` 订阅者；第二个监视订阅连接会被拒绝。

## RUP1 UDP 数据报

每个 UDP 数据报恰好包含一个 24 字节头和 0–1024 字节 payload。所有多字节整数使用网络字节序，即大端。包长必须恰好等于 `24 + payload_length`，不允许尾部填充。

| 偏移 | 长度 | 字段 | 要求 |
| --- | --- | --- | --- |
| 0 | 4 | magic | ASCII `RUP1`，十六进制 `52 55 50 31` |
| 4 | 1 | version | `1` |
| 5 | 1 | header_bytes | `24` |
| 6 | 1 | payload_type | `0`：二进制；`1`：UTF-8 文本 |
| 7 | 1 | flags | `0` |
| 8 | 4 | sequence | 收端提供的 uint32 序号，可回绕 |
| 12 | 2 | payload_length | `0–1024` |
| 14 | 2 | reserved | `0` |
| 16 | 4 | sender_ms | 收端自定义毫秒计数，uint32，可回绕 |
| 20 | 4 | crc32 | 下述 CRC，以大端存放 |
| 24 | N | payload | 原样转发；不得按 C 字符串处理 |

CRC 使用 CRC-32/ISO-HDLC，即 Python `zlib.crc32`：对 **头部字节 0–19 与 payload 的拼接**计算，跳过 CRC 字段 20–23。反射多项式为 `0xedb88320`，初始值和最终异或值均为 `0xffffffff`。

参考编码器为 `scripts/monitor_uplink.py` 的 `encode_packet(payload, sequence, sender_ms, payload_type)`，只依赖 Python 标准库。固件独立验证 magic、版本、头长、类型、保留字段、实际包长和 CRC。序号原样保留；重复、乱序和收端重启不使包失效。`sender_ms` 不表示发收端时钟已同步。UTF-8 声明不改变二进制保存方式：无效 UTF-8 仍按 hex 显示。

## PS Ethernet 监视流

TCP `7070` 发送 UTF-8 JSON Lines，每行一个对象，以单个 LF 结束。payload 始终使用 hex，无损支持 NUL、换行和任意字节。

```json
{"type":"uplink","protocol":"RUP1","sequence":7,"sender_ms":1234,"payload_type":1,"length":5,"payload_hex":"68656c6c6f"}
```

连接建立后及约每秒发送 `uplink_status`。字段包括：

| 字段 | 含义 |
| --- | --- |
| `ready` | 板级初始化、GEM1 netif 和 UDP 监听器已成功建立 |
| `link_up` | lwIP 报告的 GEM1 链路状态；不能替代实测数据通路 |
| `init_error` | `0` 成功；`-1..-7` 为板级驱动错误；`-105` 地址解析、`-106` GEM1 添加、`-107` UDP 分配、`-108` UDP 绑定、`-109` BSP 缺少 GEM1 |
| `datagrams` | 到达应用 UDP 回调的数据报数 |
| `accepted` | 通过格式与来源检查并进入队列的包数 |
| `invalid` | 格式、长度、CRC 或 pbuf 拷贝检查失败的包数 |
| `source_rejected` | 进入回调后来源/网口/目标不匹配的包数 |
| `queue_dropped` | 合法包因队列已满而丢弃的数量 |
| `forwarded` | 完整 JSON 行已由 `tcp_write(..., COPY)` 接收的包数；不代表上位机应用已保存 |
| `queued`, `queue_capacity` | 当前队列包数与容量，容量固定为 8 |
| `subscribers`, `disconnects` | 已接受订阅连接及其断开次数 |

计数器为 uint32，重启清零并允许回绕。`ready=true` 只表示初始化成功；未来仍需接入收端验证链路、吞吐、丢包和内容。

发送采用非阻塞 raw lwIP API。TCP 无发送空间或返回 `ERR_MEM` 时，队首数据保留，下次主循环重试。未连接、连接慢或断开时，最多保留 8 包，满后丢弃新包；断开后重新连接会看到仍排队的数据。已经交给 TCP 的数据不做应用层重传，断链时可能丢失。该通路用于回传内容显示，不保证持续线速、零丢包或恰好一次交付。

## 上位机使用

上位机 PS Ethernet 网卡配置在 `192.168.1.0/24`，避免占用发端 `.11`。

```bash
python3 scripts/monitor_uplink.py monitor --host 192.168.1.11
python3 scripts/monitor_uplink.py monitor --host 192.168.1.11 --jsonl received.jsonl
```

脚本显示接收时间、序号、收端时间、长度及文本/hex。文本中的终端控制字节被转义。`--jsonl` 以追加方式保存完整 JSON，并加入上位机 UTC 接收时间 `received_utc`；按 Ctrl-C 退出。默认断线后每 2 秒重连，`--no-reconnect` 可关闭重连。监视脚本不发送 RIS 控制命令。

未来没有收端固件时，可用接到 PL Ethernet 的测试电脑配置 `192.168.2.12/24`，从该电脑发送一包：

```bash
python3 scripts/monitor_uplink.py send-test --source 192.168.2.12 --target 192.168.2.11 --sequence 1 --text 'receiver hello'
python3 scripts/monitor_uplink.py send-test --source 192.168.2.12 --target 192.168.2.11 --sequence 2 --hex 000102ff
```

发送端显式绑定 UDP 源端口 `7061`。上述模拟收端的方法已用于实板验证。

## 初始化与验证范围

`ris_network_init()` 先建立原 GEM0 控制监听器，再建立监视监听器，调用 `ris_pl_eth_board_init()`，最后添加 GEM1。PL 初始化失败会在 UART 与监视状态中报告，GEM0 控制服务继续运行。板级驱动和匹配 BD/BSP 负责 Si5324、PHY reset 与 SGMII；本模块不重复初始化 PS、不重置 GEM0 PHY，也不进行烧写。

板级时钟初始化在启动时同步执行，正常至少等待约 5 秒，期间主循环尚未开始服务 TCP。I2C 单次等待有上限，并使用 20 秒总墙钟截止时间覆盖配置、读回与锁定检查，避免持续缓慢但成功的 I2C 事务放大启动等待。成功后的 PHY 释放稳定等待另需 100 ms。PHY/PCS 的链路协商由工程 BSP 负责，须同样使用有限超时。

主机离线验证入口：

```bash
python3 -B tests/run_uplink_tests.py
python3 -B tests/run_pl_eth_board_tests.py
```

测试实际编译 `ris_uplink_core.c` 和 `ris_uplink.c`，以 mock lwIP/BSP 执行链式 pbuf、来源/网口过滤、独立 zlib CRC 向量、逐字节破坏、长度/版本/保留位、0/1024 字节边界、队列溢出、TCP 背压与 `ERR_MEM`、单订阅和板初始化失败诊断。另有 8 项 Python 测试，包括 TCP 拆包/粘包、JSON 长度约束、控制字符显示，以及 localhost TCP 到真实 CLI/JSONL 文件的测试。测试不会连接开发板；发端 JTAG、匹配 BSP/ELF 和有线回传验证见 [实板测试记录](reports/pl_eth_sgmii_20261113/board_test/result.json)。

板级测试编译实际 `ris_pl_eth_board.c` 并模拟 MMIO，共 17 个场景：Si5324 和 Si5326 正常启动、未知型号、配置失败、总线忙、NACK、发送/接收停滞、MUX/芯片ID/配置读回错误、晶振丢失、未锁定、ICAL停滞、间歇锁定，以及配置阶段/锁定阶段的慢速成功 I2C。断言 GPIO 输出启用顺序、错误时不释放 PHY、GEM0 MIO47 不被改变，并验证慢速场景在模拟墙钟 20 秒退出。
