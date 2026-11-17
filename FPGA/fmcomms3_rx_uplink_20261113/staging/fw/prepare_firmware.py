from pathlib import Path

root = Path("/home/wenhan/PROJECTS/RIS/FPGA")
sender = root / "ris_qam_backend"
project = root / "fmcomms3_rx_uplink_20261113/zynq/zc706/fmcomms3_rx"
drivers = project / "vitis_code/key_ctrlll/src/drivers"

def replace_once(text, old, new):
    assert text.count(old) == 1, old
    return text.replace(old, new, 1)

for name in ("ris_pl_eth_board.c", "ris_pl_eth_board.h"):
    data = (sender / "software/network" / name).read_text()
    data = data.replace("GPIO_PHY_RESET 54U", "GPIO_PHY_RESET 55U")
    data = data.replace("GPIO_CLOCK_RESET 55U", "GPIO_CLOCK_RESET 56U")
    data = data.replace("EMIO54 PHY reset, EMIO55 clock reset", "EMIO55 PHY reset, EMIO56 clock reset")
    (drivers / name).write_text(data)

header = drivers / "rx_network.h"
header.write_text(replace_once(header.read_text(), "RX_NET_COMMAND_BYTES 192U",
                               "RX_NET_COMMAND_BYTES 2080U"))

path = drivers / "rx_network.c"
data = replace_once(path.read_text(), '#include "rx_network.h"', '#include "rx_network.h"\n#include "rx_uplink.h"')
data = replace_once(data, "    if (tcp_bind(pcb, IP_ADDR_ANY, port)", """    tcp_bind_netif(pcb, &board_netif);
    if (tcp_bind(pcb, netif_ip_addr4(&board_netif), port)""")
data = replace_once(data, """    active = 1;
    printf(""", """    active = 1;
    polling = 1; /* Keep diagnostic UART output out of raw lwIP during GEM1 setup. */
    int uplink_rc = rx_uplink_init();
    polling = 0;
    printf("\\r\\nRX PL uplink: init=%d, %s\\r\\n", uplink_rc,
           uplink_rc ? "unavailable" : "192.168.2.12:7061 -> 192.168.2.11:7061");
    printf(""")
data = replace_once(data, "    flush_streams();\n    polling = 0;",
                    "    rx_uplink_poll(now);\n    flush_streams();\n    polling = 0;")
path.write_text(data)

path = drivers / "rx_control.c"
data = replace_once(path.read_text(), '#include "rx_network.h"', '#include "rx_network.h"\n#include "rx_uplink.h"')
data = replace_once(data, "void rx_control_poll(void)", """static int hex_digit(char value)
{
    if (value >= '0' && value <= '9') return value - '0';
    if (value >= 'a' && value <= 'f') return value - 'a' + 10;
    if (value >= 'A' && value <= 'F') return value - 'A' + 10;
    return -1;
}

static int hex_payload(const char *text, uint8_t *payload, size_t *length)
{
    size_t digits = strlen(text);

    if (!strcmp(text, "-")) { *length = 0; return 0; }
    if (digits % 2U || digits > RX_UPLINK_MAX_PAYLOAD * 2U) return -1;
    *length = digits / 2U;
    for (size_t i = 0; i < *length; ++i) {
        int high = hex_digit(text[2U * i]);
        int low = hex_digit(text[2U * i + 1U]);

        if (high < 0 || low < 0) return -1;
        payload[i] = (uint8_t)((high << 4) | low);
    }
    return 0;
}

void rx_control_poll(void)""")
data = replace_once(data, '    if (count == 1U && !strcmp(word[0], "DEBUG")) {', """    if (count == 1U && !strcmp(word[0], "UPLINK_STATUS")) {
        n = snprintf(out, RX_NET_FRAME_BYTES,
            "{\\"ok\\":true,\\"type\\":\\"uplink_status\\","
            "\\"link_up\\":%s,\\"init_error\\":%d}\\n",
            rx_uplink_link_up() ? "true" : "false", rx_uplink_init_error());
        goto reply;
    }
    if (count == 4U && !strcmp(word[0], "UPLINK")) {
        uint8_t payload[RX_UPLINK_MAX_PAYLOAD];
        size_t length;

        if (number(word[1], &a) || number(word[2], &b) || b > 1U ||
            hex_payload(word[3], payload, &length)) goto bad;
        rc = rx_uplink_send(a, b, payload, length);
        n = snprintf(out, RX_NET_FRAME_BYTES,
            "{\\"ok\\":%s,\\"type\\":\\"uplink\\",\\"result\\":%d,"
            "\\"sequence\\":%u,\\"length\\":%u}\\n",
            rc ? "false" : "true", rc, (unsigned)a, (unsigned)length);
        goto reply;
    }
    if (count == 1U && !strcmp(word[0], "DEBUG")) {""")
path.write_text(data)

path = project / "host/rx706.py"
data = replace_once(path.read_text(), "RECONNECT_BYTES = 64 * 1024 * 1024", 
                    "RECONNECT_BYTES = 64 * 1024 * 1024\nUPLINK_MAX_BYTES = 1024")
data = replace_once(data, "    def read_chunk(self, capture_id, offset, length):", """    def send_uplink(self, sequence, payload):
        if type(sequence) is not int or not 0 <= sequence <= 0xffffffff:
            raise ValueError("sequence must be an unsigned 32-bit integer")
        kind = 1 if isinstance(payload, str) else 0
        data = payload.encode("utf-8") if kind else payload
        if not isinstance(data, bytes) or len(data) > UPLINK_MAX_BYTES:
            raise ValueError(f"payload must be text or bytes up to {UPLINK_MAX_BYTES} bytes")
        reply = self.request(f"UPLINK {sequence} {kind} {data.hex() or '-'}")
        if (reply.get("type"), reply.get("sequence"), reply.get("length")) != (
                "uplink", sequence, len(data)):
            raise ProtocolError("uplink reply does not match the request")
        return reply

    def read_chunk(self, capture_id, offset, length):""")
data = replace_once(data, '    commands.add_parser("status")', """    commands.add_parser("status")
    commands.add_parser("uplink-status", help="check J18 initialization and link")
    uplink = commands.add_parser("uplink", help="send a RUP1 datagram via the J18 PL port")
    uplink.add_argument("--sequence", required=True, type=int)
    payload = uplink.add_mutually_exclusive_group(required=True)
    payload.add_argument("--text")
    payload.add_argument("--hex")""")
data = replace_once(data, '        elif args.command == "debug":', """        elif args.command == "uplink-status":
            print(json.dumps(client.request("UPLINK_STATUS"), indent=2))
        elif args.command == "uplink":
            data = args.text if args.text is not None else bytes.fromhex(args.hex)
            print(json.dumps(client.send_uplink(args.sequence, data), indent=2))
        elif args.command == "debug":""")
path.write_text(data)

(project / "scripts/patch_uplink_bsp.py").write_bytes((sender / "scripts/patch_uplink_bsp.py").read_bytes())
