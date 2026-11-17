#!/usr/bin/env python3
"""Display the transmitter's RUP1 telemetry; no RIS control commands are sent."""
import argparse
from datetime import datetime, timezone
import json
import socket
import struct
import sys
import time
import zlib

MAX_PAYLOAD = 1024
MAX_LINE = 4096


def encode_packet(payload, sequence=0, sender_ms=0, payload_type=0):
    """RUP1: network byte order; CRC excludes the four-byte CRC field."""
    if not isinstance(payload, bytes) or len(payload) > MAX_PAYLOAD:
        raise ValueError("payload must be bytes, at most 1024 bytes")
    for name, value in (("sequence", sequence), ("sender_ms", sender_ms)):
        if type(value) is not int or not 0 <= value <= 0xFFFFFFFF:
            raise ValueError(f"{name} must be an unsigned 32-bit integer")
    if type(payload_type) is not int or payload_type not in (0, 1):
        raise ValueError("payload_type must be 0 (binary) or 1 (UTF-8)")
    header = struct.pack("!4sBBBBIHHI", b"RUP1", 1, 24, payload_type, 0,
                         sequence, len(payload), 0, sender_ms)
    crc = zlib.crc32(payload, zlib.crc32(header)) & 0xFFFFFFFF
    return header + struct.pack("!I", crc) + payload


def _uint(message, key, maximum=0xFFFFFFFF):
    value = message.get(key)
    if type(value) is not int or not 0 <= value <= maximum:
        raise ValueError(f"invalid {key}")
    return value


def decode_message(line):
    if len(line) > MAX_LINE:
        raise ValueError("oversize JSON line")
    message = json.loads(line.decode("utf-8"))
    if not isinstance(message, dict) or message.get("protocol") != "RUP1":
        raise ValueError("unsupported telemetry protocol")
    if message.get("type") == "uplink":
        _uint(message, "sequence")
        _uint(message, "sender_ms")
        _uint(message, "payload_type", 1)
        length = _uint(message, "length", MAX_PAYLOAD)
        encoded = message.get("payload_hex")
        if not isinstance(encoded, str) or len(encoded) != length * 2:
            raise ValueError("payload length does not match hex data")
        if any(c not in "0123456789abcdefABCDEF" for c in encoded):
            raise ValueError("invalid payload hex")
        payload = bytes.fromhex(encoded)
        if len(payload) != length:
            raise ValueError("invalid decoded payload length")
    elif message.get("type") == "uplink_status":
        for key in ("ready", "link_up"):
            if type(message.get(key)) is not bool:
                raise ValueError(f"invalid {key}")
        if type(message.get("init_error")) is not int:
            raise ValueError("invalid init_error")
        for key in ("datagrams", "accepted", "invalid", "source_rejected",
                    "queue_dropped", "forwarded", "queued", "queue_capacity",
                    "subscribers", "disconnects"):
            _uint(message, key)
        if message["queued"] > message["queue_capacity"]:
            raise ValueError("invalid queue occupancy")
    else:
        raise ValueError("unknown message type")
    return message


class JsonLinesReader:
    def __init__(self):
        self.pending = bytearray()

    def feed(self, data):
        """Accept arbitrary TCP splits/coalescing with a bounded line buffer."""
        messages = []
        for fragment in data.splitlines(keepends=True):
            self.pending.extend(fragment)
            if len(self.pending) > MAX_LINE:
                raise ValueError("oversize or unterminated JSON line")
            if self.pending.endswith(b"\n"):
                messages.append(decode_message(bytes(self.pending[:-1])))
                self.pending.clear()
        return messages

    def finish(self):
        if self.pending:
            raise ValueError("connection ended inside a JSON line")


def format_message(message):
    if message["type"] == "uplink_status":
        return (f"status ready={message['ready']} link={message['link_up']} "
                f"init_error={message['init_error']} rx={message['datagrams']} "
                f"forwarded={message['forwarded']} queued={message['queued']} "
                f"queue_dropped={message['queue_dropped']} "
                f"invalid={message['invalid']} source_rejected={message['source_rejected']}")
    payload = bytes.fromhex(message["payload_hex"])
    if message["payload_type"] == 1:
        try:
            # JSON quoting preserves control bytes and prevents terminal escapes.
            content = "text=" + json.dumps(payload.decode("utf-8"), ensure_ascii=False)
        except UnicodeDecodeError:
            content = "invalid_utf8 hex=" + payload.hex()
    else:
        content = "hex=" + payload.hex()
    return (f"seq={message['sequence']} sender_ms={message['sender_ms']} "
            f"bytes={len(payload)} {content}")


def monitor(args):
    output = open(args.jsonl, "a", encoding="utf-8") if args.jsonl else None
    try:
        while True:
            try:
                with socket.create_connection((args.host, args.port), timeout=5) as sock:
                    print(f"connected {args.host}:{args.port}", file=sys.stderr)
                    sock.settimeout(2)
                    reader = JsonLinesReader()
                    while True:
                        try:
                            data = sock.recv(4096)
                        except socket.timeout:
                            continue
                        if not data:
                            reader.finish()
                            raise ConnectionError("server closed the connection")
                        for message in reader.feed(data):
                            stamp = datetime.now(timezone.utc).isoformat(timespec="milliseconds")
                            print(f"{stamp} {format_message(message)}", flush=True)
                            if output:
                                output.write(json.dumps(dict(received_utc=stamp, **message),
                                                        ensure_ascii=False) + "\n")
                                output.flush()
            except (OSError, ValueError) as error:
                print(f"monitor: {error}", file=sys.stderr)
                if args.no_reconnect:
                    return 1
                time.sleep(2)
    except KeyboardInterrupt:
        return 0
    finally:
        if output:
            output.close()


def send_test(args):
    payload = bytes.fromhex(args.hex) if args.hex is not None else args.text.encode("utf-8")
    packet = encode_packet(payload, args.sequence,
                           int(time.monotonic() * 1000) & 0xFFFFFFFF,
                           0 if args.hex is not None else 1)
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        # Explicit bind matches the transmitter's source IP/port allow-list.
        sock.bind((args.source, 7061))
        sock.sendto(packet, (args.target, 7061))
    print(f"sent one RUP1 datagram: {len(payload)} payload bytes, sequence {args.sequence}")
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    watch = commands.add_parser("monitor", help="display PS Ethernet telemetry")
    watch.add_argument("--host", default="192.168.1.11")
    watch.add_argument("--port", type=int, default=7070)
    watch.add_argument("--jsonl", help="append received messages to this file")
    watch.add_argument("--no-reconnect", action="store_true")
    watch.set_defaults(run=monitor)
    send = commands.add_parser("send-test", help="send one packet from a future receiver/test laptop")
    send.add_argument("--target", default="192.168.2.11")
    send.add_argument("--source", default="192.168.2.12")
    send.add_argument("--sequence", type=int, default=0)
    data = send.add_mutually_exclusive_group(required=True)
    data.add_argument("--text")
    data.add_argument("--hex")
    send.set_defaults(run=send_test)
    args = parser.parse_args(argv)
    try:
        return args.run(args)
    except (ValueError, OSError) as error:
        parser.exit(2, f"error: {error}\n")


if __name__ == "__main__":
    sys.exit(main())
