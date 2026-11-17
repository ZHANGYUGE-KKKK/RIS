from pathlib import Path

project = Path("/home/wenhan/PROJECTS/RIS/FPGA/fmcomms3_rx_uplink_20261113/zynq/zc706/fmcomms3_rx")
app = project / "vitis_code/key_ctrlll/src"
drivers = app / "drivers"

def edit(path, replacements):
    content = path.read_text()
    for old, new in replacements:
        assert content.count(old) == 1, old
        content = content.replace(old, new, 1)
    path.write_text(content)

edit(drivers / "rx_control.c", [
    ('#include "rx_uplink.h"', '#include "rx_uplink.h"\n#include "rx_pwm3_service.h"'),
    ('    if (!rx_network_take_request(command, &ticket)) return;',
     '    if (!rx_network_take_request(command, &ticket)) { rx_pwm3_poll(); return; }'),
    ('    if (count == 1U && !strcmp(word[0], "UPLINK_STATUS")) {', '''    if (count == 1U && !strcmp(word[0], "PWM3_STATUS")) {
        n = rx_pwm3_status(out, RX_NET_FRAME_BYTES);
        goto reply;
    }
    if (count == 1U && !strcmp(word[0], "PWM3_START")) {
        if (!rx_pwm3_start()) n = rx_pwm3_status(out, RX_NET_FRAME_BYTES);
        else n = snprintf(out, RX_NET_FRAME_BYTES,
            "{\\"ok\\":false,\\"error\\":\\"RF capture unavailable or busy\\"}\\n");
        goto reply;
    }
    if (count == 1U && !strcmp(word[0], "PWM3_STOP")) {
        rx_pwm3_stop();
        n = rx_pwm3_status(out, RX_NET_FRAME_BYTES);
        goto reply;
    }
    if (count == 1U && !strcmp(word[0], "UPLINK_STATUS")) {'''),
    ('        capture_store_abort(); rc = 0;', '        rx_pwm3_stop(); capture_store_abort(); rc = 0;'),
])

edit(app / "helloworld.c", [
    ('#include "drivers/rx_control.h"', '#include "drivers/rx_control.h"\n#include "drivers/rx_pwm3_service.h"'),
    ('''    if (key != 'c' && key != 'C' && key != 'v' && key != 'V') return 0;''', '''    if (key == 'p' || key == 'P') {
        status = rx_pwm3_start();
        xil_printf("RX PWM3 start=%d; use x to stop\\r\\n", status);
        return 1;
    }
    if (key == 'x' || key == 'X') {
        rx_pwm3_stop();
        xil_printf("RX PWM3 stopped\\r\\n");
        return 1;
    }
    if (key != 'c' && key != 'C' && key != 'v' && key != 'V') return 0;'''),
    ('r=release d=debug g=gain s=snapshot t=three-step test',
     'r=release d=debug g=gain s=snapshot t=three-step test p=PWM3 start x=stop'),
])

edit(project / "host/rx706.py", [
    ('    commands.add_parser("uplink-status",', '''    commands.add_parser("pwm3-start", help="start periodic on-board PWM3 demodulation")
    commands.add_parser("pwm3-status", help="read PWM3 capture, decode and uplink counters")
    commands.add_parser("pwm3-stop", help="stop periodic PWM3 capture")
    commands.add_parser("uplink-status",'''),
    ('        elif args.command == "uplink-status":', '''        elif args.command in ("pwm3-start", "pwm3-status", "pwm3-stop"):
            print(json.dumps(client.request(args.command.upper().replace("-", "_")), indent=2))
        elif args.command == "uplink-status":'''),
])
