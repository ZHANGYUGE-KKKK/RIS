import json
import runpy
import socket
import time
from pathlib import Path


root = Path('/home/wenhan/PROJECTS/RIS/FPGA/ris_qam_backend')
encode = runpy.run_path(str(root / 'scripts/monitor_uplink.py'))['encode_packet']
ps_host = '192.168.1.11'
pl_host = '192.168.2.11'
pl_source = '192.168.2.12'
port = 7061


def connect(port_number, seconds):
    deadline = time.monotonic() + seconds
    while True:
        try:
            return socket.create_connection((ps_host, port_number), timeout=2)
        except OSError:
            if time.monotonic() >= deadline:
                raise
            time.sleep(0.5)


def report(label, value):
    print(label, json.dumps(value, ensure_ascii=False, sort_keys=True), flush=True)


def next_record(stream):
    line = stream.readline(4096)
    if not line.endswith(b'\n'):
        raise RuntimeError('Incomplete JSON record from the board')
    return json.loads(line)


with connect(7060, 20) as control, control.makefile('rb') as stream:
    control.sendall(b'1 STATUS\n')
    control_status = next_record(stream)
    report('PS_CONTROL_STATUS', control_status)
    if control_status.get('ok') is not True or control_status.get('errors') != 0:
        raise RuntimeError('RIS control status failed')

with connect(7070, 12) as monitor, monitor.makefile('rb') as stream:
    monitor.settimeout(4)
    deadline = time.monotonic() + 20
    while time.monotonic() < deadline:
        baseline = next_record(stream)
        if baseline.get('type') != 'uplink_status':
            continue
        report('UPLINK_BASELINE', baseline)
        if baseline.get('init_error') != 0:
            raise RuntimeError(f"PL init error {baseline.get('init_error')}")
        if baseline.get('ready') and baseline.get('link_up'):
            break
    else:
        raise RuntimeError('The board did not report an operational GEM1 link')

    expected = {1001: (b'RIS J18 board test', 1), 1002: (bytes(range(256)) * 4, 0)}
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sender:
        sender.bind((pl_source, port))
        for sequence, (payload, payload_type) in expected.items():
            packet = encode(payload, sequence, 1234, payload_type)
            sender.sendto(packet, (pl_host, port))
        bad_crc = bytearray(encode(b'corrupt', 1003, 1234, 0))
        bad_crc[-1] ^= 1
        sender.sendto(bad_crc, (pl_host, port))

    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as wrong_source:
        wrong_source.bind((pl_source, 0))
        wrong_source.sendto(encode(b'wrong source port', 1004, 1234, 1), (pl_host, port))

    matched = set()
    deadline = time.monotonic() + 12
    while time.monotonic() < deadline:
        record = next_record(stream)
        if record.get('type') == 'uplink':
            sequence = record.get('sequence')
            if sequence in (1003, 1004):
                raise RuntimeError(f'Rejected packet was forwarded: {sequence}')
            if sequence not in expected:
                continue
            payload, payload_type = expected[sequence]
            if (record.get('protocol') != 'RUP1' or record.get('sender_ms') != 1234
                    or record.get('payload_type') != payload_type
                    or record.get('length') != len(payload)
                    or bytes.fromhex(record['payload_hex']) != payload):
                raise RuntimeError(f'Forwarded content mismatch: {sequence}')
            matched.add(sequence)
            report('PAYLOAD_MATCH', {'sequence': sequence, 'length': len(payload)})
        elif record.get('type') == 'uplink_status':
            deltas = {key: record[key] - baseline[key] for key in (
                'datagrams', 'accepted', 'forwarded', 'invalid', 'source_rejected', 'queue_dropped'
            )}
            if (matched == expected.keys() and deltas == dict(datagrams=4, accepted=2,
                    forwarded=2, invalid=1, source_rejected=1, queue_dropped=0)):
                report('UPLINK_COUNTER_DELTAS', deltas)
                print('RIS_J18_END_TO_END_PASS', flush=True)
                break
    else:
        raise RuntimeError('Payloads or expected rejection counters did not arrive')
