#!/usr/bin/python3
"""Exercise the real UART application; requires exclusive access to the port."""
import os
from pathlib import Path
import re
import select
import sys
import termios
import time

port = sys.argv[1] if len(sys.argv) > 1 else "/dev/ttyUSB0"
root = Path(__file__).resolve().parents[1]
log_path = root / "reports/board_v1/uart.log"
log_path.parent.mkdir(parents=True, exist_ok=True)
received = bytearray()
fd = None


def collect(seconds):
    data = bytearray()
    until = time.monotonic() + seconds
    while time.monotonic() < until:
        ready, _, _ = select.select([fd], [], [], max(0, until - time.monotonic()))
        if ready:
            chunk = os.read(fd, 4096)
            data.extend(chunk)
            received.extend(chunk)
    return data.decode("ascii", errors="replace")


status_re = re.compile(r"RIS rc=(-?\d+) pattern=(HIGH|LOW) status=([0-9a-fA-F]+) errors=([0-9a-fA-F]+) frames=(\d+)")


def send(command, pattern=None, enabled=True):
    os.write(fd, command.encode("ascii") + b"\n")
    response = collect(0.25)
    matches = list(status_re.finditer(response))
    if not matches:
        response += collect(2)
        matches = list(status_re.finditer(response))
    assert matches, f"No UART response to {command!r}: {response!r}"
    rc, got_pattern, status, errors, frames = matches[-1].groups()
    assert int(rc) == 0 and int(errors, 16) == 0, response
    assert int(status, 16) & 0xff == (0xc2 if enabled else 0x42), response
    if pattern is not None:
        assert got_pattern == pattern, response
    print(f"PASS UART {command}: {got_pattern}, frame={frames}, status={status}")
    return int(frames)


try:
    fd = os.open(port, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    attrs = termios.tcgetattr(fd)
    attrs[0] = 0
    attrs[1] = 0
    attrs[2] = termios.CLOCAL | termios.CREAD | termios.CS8
    attrs[3] = 0
    attrs[4] = attrs[5] = termios.B115200
    attrs[6][termios.VMIN] = 0
    attrs[6][termios.VTIME] = 0
    termios.tcsetattr(fd, termios.TCSANOW, attrs)
    collect(0.1)
    previous = send("0", "LOW")
    assert send("1", "HIGH") == previous + 1
    before_blink = send("b", "HIGH")
    toggles = list(status_re.finditer(collect(2.3)))
    assert len(toggles) >= 2, "One-second toggle did not produce two updates"
    assert {m.group(2) for m in toggles} == {"HIGH", "LOW"}, "Toggle did not alternate"
    assert int(toggles[-1].group(5)) >= before_blink + 2
    for match in toggles:
        assert int(match.group(1)) == 0 and int(match.group(4), 16) == 0
    previous = send("0", "LOW")
    assert not status_re.search(collect(1.2)), "Static command did not stop toggling"
    assert send("s", "LOW") == previous
    assert send("d", "LOW", enabled=False) == previous
    assert send("e", "LOW") == previous
    print("RIS_UART_TEST_PASS: 0/1/b/s/d/e; real USB UART; final all LOW")
    received.extend(b"\nRIS_UART_TEST_PASS\n")
finally:
    if fd is not None:
        try:
            os.write(fd, b"0\n")
            collect(0.2)
        except OSError:
            pass
        finally:
            os.close(fd)
    log_path.write_bytes(received)
