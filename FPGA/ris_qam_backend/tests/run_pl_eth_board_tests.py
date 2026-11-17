#!/usr/bin/env python3
"""Compile the actual PL Ethernet board driver against deterministic MMIO mocks."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    bundled = "/home/wenhan/SOFTWARE/VIVADO2022.2/Vivado/2022.2/tps/lnx64/gcc-8.3.0/bin/gcc"
    compiler = os.environ.get("RIS_HOST_GCC") or shutil.which("cc") or bundled
    with tempfile.TemporaryDirectory(prefix="ris-pl-eth-board-test-") as temp:
        command = [compiler, "-std=c99", "-O2", "-Wall", "-Wextra", "-Werror",
                   "-I" + str(ROOT / "tests/pl_eth_board")]
        if sys.platform.startswith("linux"):
            command += ["-isystem", "/usr/include/x86_64-linux-gnu", "-B/usr/lib/x86_64-linux-gnu/"]
        executable = str(Path(temp) / "test_board")
        command += [str(ROOT / "tests/pl_eth_board/test_board.c"), "-o", executable]
        subprocess.run(command, check=True)
        subprocess.run([executable], check=True, timeout=30)


if __name__ == "__main__":
    main()
