"""Real firmware C parser/driver behind a host-only AXI model; never a board."""
from pathlib import Path
import json
import subprocess
import threading

BACKEND = Path(__file__).resolve().parents[3] / "FPGA/ris_qam_backend"


class DeviceModel:
    def __init__(self):
        self.process = subprocess.Popen([str(BACKEND / "build/protocol/qam_model_server")],
                                        stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
        self.lock = threading.Lock()
        self.sequence = 0
        self.commands = []

    def exchange(self, line):
        with self.lock:
            self.process.stdin.write(line.rstrip("\n") + "\n")
            self.process.stdin.flush()
            result = self.process.stdout.readline()
            if not result:
                raise RuntimeError(f"firmware model stopped: {self.process.poll()}")
            return result

    def command(self, command):
        self.commands.append(command)
        self.sequence += 1
        return json.loads(self.exchange(f"{self.sequence} {command}"))

    def close(self):
        self.process.stdin.close()
        self.process.wait(timeout=3)
        self.process.stdout.close()
        if self.process.returncode:
            raise AssertionError(f"firmware model exit {self.process.returncode}")
