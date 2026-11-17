import os
import select
import termios
import time

device = "/dev/serial/by-id/usb-Silicon_Labs_CP2103_USB_to_UART_Bridge_Controller_0001-if00-port0"
end = time.monotonic() + 600
print("UART_COLD_WATCH", flush=True)
while time.monotonic() < end:
    try:
        fd = os.open(device, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    except (FileNotFoundError, PermissionError):
        time.sleep(0.2)
        continue
    try:
        settings = termios.tcgetattr(fd)
        settings[0] = settings[1] = settings[3] = 0
        settings[2] = termios.CLOCAL | termios.CREAD | termios.CS8
        settings[4] = settings[5] = termios.B115200
        settings[6][termios.VMIN] = settings[6][termios.VTIME] = 0
        termios.tcsetattr(fd, termios.TCSANOW, settings)
        print("UART_COLD_READY 115200 8N1", flush=True)
        while time.monotonic() < end:
            if select.select([fd], [], [], 0.5)[0]:
                chunk = os.read(fd, 4096)
                if not chunk:
                    break
                os.write(1, chunk)
    except OSError:
        time.sleep(0.2)
    finally:
        os.close(fd)
