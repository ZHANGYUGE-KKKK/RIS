#!/usr/bin/env python3
"""Host-only tests. No Vivado, programming cable, board, or external networking."""
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile
import zlib

ROOT = Path(__file__).resolve().parents[1]


def packet(payload, **overrides):
    fields = dict(magic=b"RUP1", version=1, header_bytes=24, payload_type=1,
                  flags=0, sequence=0x12345678, length=len(payload), reserved=0,
                  sender_ms=0x90ABCDEF)
    fields.update(overrides)
    first = struct.pack("!4sBBBBIHHI", *fields.values())
    return first + struct.pack("!I", zlib.crc32(first + payload) & 0xFFFFFFFF) + payload


def run():
    bundled = Path("/home/wenhan/SOFTWARE/VIVADO2022.2/Vivado/2022.2/tps/lnx64/gcc-8.3.0/bin/gcc")
    compiler = os.environ.get("RIS_HOST_GCC") or shutil.which("cc") or str(bundled)
    if not shutil.which(compiler):
        raise SystemExit(f"host C compiler unavailable: {compiler}")
    with tempfile.TemporaryDirectory(prefix="ris-uplink-tests-") as directory:
        temp = Path(directory)
        for name in ("xtime_l.h", "xil_types.h", "xparameters.h", "ris_pl_eth_board.h",
                     "lwip/tcp.h", "lwip/udp.h", "lwip/ip.h", "lwip/inet.h",
                     "netif/xadapter.h", "netif/xemacpsif.h"):
            path = temp / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('#include "uplink_mock.h"\n')
        payload = b"a\0b\n\x1b"
        vectors = {"vector_small": packet(payload), "vector_empty": packet(b""),
                   "vector_max": packet(bytes(range(256)) * 4)}
        header = "".join(f"static const unsigned char {name}[] = {{" +
                         ",".join(str(byte) for byte in data) + "};\n"
                         for name, data in vectors.items())
        invalid = [packet(payload, **changes) for changes in
                   ({"version": 2}, {"header_bytes": 23}, {"payload_type": 2},
                    {"flags": 1}, {"reserved": 1}, {"length": 4}, {"magic": b"STOP"})]
        header += "static const unsigned char invalid_packets[][29] = {" + ",".join(
            "{" + ",".join(str(byte) for byte in data) + "}" for data in invalid) + "};\n"
        (temp / "uplink_vectors.h").write_text(header)
        command = [compiler, "-std=c99", "-O2", "-Wall", "-Wextra", "-Werror",
                   "-I" + str(temp), "-I" + str(ROOT / "tests/uplink_stubs")]
        if sys.platform.startswith("linux"):
            command += ["-isystem", "/usr/include/x86_64-linux-gnu",
                        "-B/usr/lib/x86_64-linux-gnu/"]
        command += [str(ROOT / "tests/test_uplink_network.c"),
                    str(ROOT / "software/network/ris_uplink_core.c"),
                    "-o", str(temp / "test_uplink")]
        print("Compiling actual RUP1 parser and lwIP adapter with host mocks", flush=True)
        subprocess.run(command, check=True)
        subprocess.run([str(temp / "test_uplink")], check=True)
    subprocess.run([sys.executable, "-B", str(ROOT / "tests/test_monitor_uplink.py"), "-v"], check=True)
    print("RIS_UPLINK_HOST_TEST_PASS", flush=True)


if __name__ == "__main__":
    run()
