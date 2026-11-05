#!/usr/bin/env python3
"""Temporary exclusive UART console; CuteCom stays open with its port closed."""
import sys,select,json,time
from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
import serial
root=Path(__file__).resolve().parent
uart=serial.Serial(port=None,baudrate=115200,timeout=0,write_timeout=2,exclusive=True)
uart.dtr=False;uart.rts=False;uart.port='/dev/ttyUSB0';uart.open()
print('HOST UART OPEN 115200 8N1; keys g s d q c v r; exit closes port',flush=True)
with (root/'serial/live.log').open('ab',buffering=0) as log, (root/'serial/events.jsonl').open('a',buffering=1) as events:
 try:
  while True:
   ready,_,_=select.select([uart.fileno(),sys.stdin],[],[],.25)
   if uart.fileno() in ready:
    data=uart.read(max(uart.in_waiting,1))
    if data:
     log.write(data);sys.stdout.write(data.decode('utf-8','replace'));sys.stdout.flush()
   if sys.stdin in ready:
    command=sys.stdin.readline().strip()
    if command=='exit' or not command:break
    if command not in ['g','s','d','q','c','v','r']:
     print('HOST rejected unsupported key',flush=True);continue
    events.write(json.dumps({'time':datetime.now(ZoneInfo('Asia/Shanghai')).isoformat(),'send':command})+'\n')
    uart.write(command.encode('ascii'));uart.flush()
    print('HOST SENT '+command,flush=True)
 finally:
  uart.close();print('HOST UART CLOSED',flush=True)
