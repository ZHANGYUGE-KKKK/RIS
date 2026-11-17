import os
import select
import sys
import termios
import time


device = '/dev/serial/by-id/usb-Silicon_Labs_CP2103_USB_to_UART_Bridge_Controller_0001-if00-port0'
fd = os.open(device, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
original = termios.tcgetattr(fd)
attributes = termios.tcgetattr(fd)
attributes[0] = 0
attributes[1] = 0
attributes[2] = termios.CLOCAL | termios.CREAD | termios.CS8
attributes[3] = 0
attributes[4] = termios.B115200
attributes[5] = termios.B115200
attributes[6][termios.VMIN] = 0
attributes[6][termios.VTIME] = 0

try:
    termios.tcsetattr(fd, termios.TCSANOW, attributes)
    print('UART_READY 115200 8N1', flush=True)
    deadline = time.monotonic() + 540
    while (remaining := deadline - time.monotonic()) > 0:
        readable, _, _ = select.select([fd], [], [], min(1, remaining))
        if readable:
            chunk = os.read(fd, 4096)
            if chunk:
                sys.stdout.buffer.write(chunk)
                sys.stdout.buffer.flush()
finally:
    termios.tcsetattr(fd, termios.TCSANOW, original)
    os.close(fd)
