#!/usr/bin/env python3
"""ZC706 raw-IQ control/download client. Python standard library only."""
import argparse
import codecs
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import socket
import sys
import threading
import time
import zlib

MAX_BYTES = 2044 * 1024 * 1024
CHUNK_BYTES = 256 * 1024
PACKET_BYTES = 32768
RECONNECT_BYTES = 64 * 1024 * 1024


class ProtocolError(RuntimeError):
    pass


class TransferCancelled(RuntimeError):
    """Stopped at a checkpoint boundary; the partial file remains resumable."""


def _check_cancel(cancel_event):
    if cancel_event is not None and cancel_event.is_set():
        raise TransferCancelled("下载已暂停，保留部分文件，可使用同一路径续传")


class Client:
    def __init__(self, host, port=5001, timeout=30):
        self.host, self.port, self.timeout = host, port, timeout
        self._connect()

    def _connect(self):
        self.socket = socket.create_connection((self.host, self.port), self.timeout)
        self.socket.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        self.stream = self.socket.makefile("rb")

    def close(self):
        try:
            self.stream.close()
        finally:
            self.socket.close()

    def reconnect(self):
        timeout = self.socket.gettimeout()
        self.close()
        # The raw lwIP server releases its single control slot on peer FIN.
        time.sleep(0.05)
        self._connect()
        self.socket.settimeout(timeout)

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.close()

    def request(self, command):
        if "\n" in command or "\r" in command:
            raise ValueError("command must be one line")
        self.socket.sendall(command.encode("ascii") + b"\n")
        line = self.stream.readline(8193)
        if not line or len(line) > 8192 or not line.endswith(b"\n"):
            raise ProtocolError("missing/truncated/oversized response header")
        try:
            reply = json.loads(line)
        except (ValueError, UnicodeError) as exc:
            raise ProtocolError("invalid JSON response") from exc
        if not isinstance(reply, dict) or reply.get("ok") is not True:
            raise ProtocolError(f"board rejected command: {reply}")
        return reply

    def read_chunk(self, capture_id, offset, length):
        if not 0 < length <= CHUNK_BYTES:
            raise ValueError("invalid chunk length")
        header = self.request(f"READ {capture_id} {offset} {length}")
        if (header.get("type") != "data" or header.get("capture_id") != capture_id
                or header.get("offset") != offset or header.get("length") != length):
            raise ProtocolError("chunk ID/offset/length does not match request")
        data = self.stream.read(length)
        if len(data) != length:
            raise ProtocolError("connection closed inside chunk; retry with --resume")
        crc = f"{zlib.crc32(data) & 0xffffffff:08x}"
        if header.get("crc32") != crc:
            raise ProtocolError("chunk CRC32 mismatch; retry with --resume")
        return data, crc


def validate_capture(info):
    size = info.get("bytes")
    if (info.get("protocol") != 1 or info.get("state") != "ready"
            or info.get("result") != 0 or info.get("reset_verified") != 1
            or type(size) is not int or not 0 < size <= MAX_BYTES or size % PACKET_BYTES
            or info.get("received_bytes") != size
            or info.get("completed_packets") != size // PACKET_BYTES
            or info.get("packets") != size // PACKET_BYTES
            or info.get("tuples") != size // 8
            or info.get("dtype") != "int16" or info.get("byte_order") != "little"
            or info.get("order") != ["I1", "Q1", "I2", "Q2"]
            or info.get("channels") != 2 or info.get("valid_bits") != 12
            or info.get("sample_rate_hz") != 15360000
            or not isinstance(info.get("capture_id"), str)
            or len(info["capture_id"]) != 16
            or any(c not in "0123456789abcdef" for c in info["capture_id"])):
        raise ProtocolError("capture is incomplete, invalid, or has an unsupported format")
    return size


def atomic_json(path, obj):
    temporary = path.with_name(path.name + ".tmp")
    with temporary.open("w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)
        f.write("\n")
    os.replace(temporary, path)


def download(client, output, *, resume=False, note="", progress=True,
             progress_callback=None, cancel_event=None):
    _check_cancel(cancel_event)
    info = client.request("STATUS")
    size = validate_capture(info)
    output = Path(output)
    metadata = output.with_suffix(output.suffix + ".json")
    partial = output.with_name(output.name + ".part")
    checkpoint = output.with_name(output.name + ".part.json")
    if output.exists() or metadata.exists():
        raise FileExistsError(f"output already exists: {output}")
    output.parent.mkdir(parents=True, exist_ok=True)
    digest = hashlib.sha256()
    if resume:
        saved = json.loads(checkpoint.read_text(encoding="utf-8"))
        # Exact source identity and layout must match, including configuration.
        for key in ("capture_id", "bytes", "rf_before", "rf_after", "sample_rate_hz", "data_base",
                    "rx_lo_config_hz"):
            if saved["capture"].get(key) != info.get(key):
                raise ProtocolError("DDR capture changed; refusing to append to old partial file")
        done = saved["received_bytes"]
        crcs = saved["chunk_crc32"]
        if (type(done) is not int or not 0 <= done <= size
                or (done != size and done % CHUNK_BYTES)
                or len(crcs) != (done + CHUNK_BYTES - 1) // CHUNK_BYTES):
            raise ProtocolError("invalid resume checkpoint")
        with partial.open("rb") as f:
            for index, crc in enumerate(crcs):
                _check_cancel(cancel_event)
                expected = min(CHUNK_BYTES, done - index * CHUNK_BYTES)
                block = f.read(expected)
                if len(block) != expected or f"{zlib.crc32(block) & 0xffffffff:08x}" != crc:
                    raise ProtocolError("partial file failed local CRC verification")
                digest.update(block)
                if progress_callback:
                    progress_callback(min((index + 1) * CHUNK_BYTES, done), done, 0, "verify")
        if partial.stat().st_size < done:
            raise ProtocolError("partial file is shorter than checkpoint")
    else:
        if partial.exists() or checkpoint.exists():
            raise FileExistsError("partial download exists; use --resume or a different output")
        done, crcs = 0, []
        saved = {"capture": info, "received_bytes": 0, "chunk_crc32": [], "note": note}
        with partial.open("xb"):
            pass
        atomic_json(checkpoint, saved)
    start, initial = time.monotonic(), done
    transport = saved.setdefault("transport", {"read_timeouts": 0, "connection_rotations": 0})

    def reconnect_frozen():
        _check_cancel(cancel_event)
        client.reconnect()
        current = client.request("STATUS")
        validate_capture(current)
        for key in ("capture_id", "bytes", "rf_before", "rf_after", "sample_rate_hz",
                    "data_base", "rx_lo_config_hz"):
            if current.get(key) != info.get(key):
                raise ProtocolError("DDR capture changed during reconnect")

    if progress_callback:
        progress_callback(done, size, 0, "download")
    with partial.open("r+b") as f:
        # Discard an uncommitted tail left after a crash between write/checkpoint.
        f.truncate(done)
        f.seek(done)
        while done < size:
            _check_cancel(cancel_event)
            for retry in range(3):
                try:
                    data, crc = client.read_chunk(info["capture_id"], done, min(CHUNK_BYTES, size - done))
                    break
                except TimeoutError:
                    _check_cancel(cancel_event)
                    if retry == 2:
                        raise
                    transport["read_timeouts"] += 1
                    # READ is idempotent for a frozen capture. Discard any
                    # incomplete chunk and repeat its exact ID/offset/length.
                    # CRC/protocol errors remain fatal and are never hidden.
                    reconnect_frozen()
            f.write(data)
            f.flush()
            digest.update(data)
            done += len(data)
            crcs.append(crc)
            saved.update(received_bytes=done, chunk_crc32=crcs)
            atomic_json(checkpoint, saved)
            if progress_callback:
                elapsed = max(time.monotonic() - start, 0.001)
                progress_callback(done, size, (done - initial) / elapsed, "download")
            if progress:
                elapsed = max(time.monotonic() - start, 0.001)
                print(f"\r{done / size:6.1%}  {done / 1048576:.2f}/{size / 1048576:.2f} MiB  "
                      f"{(done-initial) / elapsed / 1048576:.2f} MiB/s", end="", file=sys.stderr, flush=True)
            if done < size and RECONNECT_BYTES and done % RECONNECT_BYTES == 0:
                # Bound the lifetime of the board's observed stalled long TCP
                # sessions without changing the frozen DDR or sampling state.
                reconnect_frozen()
                transport["connection_rotations"] += 1
        os.fsync(f.fileno())
    # Check the frozen capture identity once more before publishing the file.
    _check_cancel(cancel_event)
    final = client.request("STATUS")
    validate_capture(final)
    if final["capture_id"] != info["capture_id"] or final["bytes"] != size:
        raise ProtocolError("capture changed during download")
    # The initial snapshot predates READ diagnostics. Preserve the final
    # counters too, without changing the frozen source identity used by resume.
    saved["capture_final"] = final
    if info.get("debug_version") == 1:
        debug = client.request("DEBUG")
        if debug.get("capture_id") != info["capture_id"]:
            raise ProtocolError("diagnostic record belongs to another capture")
        saved["debug"] = debug
    _check_cancel(cancel_event)
    saved.update(complete=True, sha256=digest.hexdigest(), file_bytes=size,
                 saved_utc=datetime.now(timezone.utc).isoformat())
    atomic_json(metadata, saved)
    os.replace(partial, output)
    checkpoint.unlink()
    if progress:
        print(file=sys.stderr)
    if progress_callback:
        progress_callback(size, size, 0, "complete")
    return saved


def console(host, port, timeout):
    with socket.create_connection((host, port), timeout) as connection:
        connection.settimeout(None)
        connection.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        ended = threading.Event()

        def receive():
            decoder = codecs.getincrementaldecoder("utf-8")("replace")
            try:
                while True:
                    data = connection.recv(8192)
                    if not data:
                        break
                    sys.stdout.write(decoder.decode(data))
                    sys.stdout.flush()
            except OSError:
                pass
            finally:
                ended.set()

        threading.Thread(target=receive, daemon=True).start()
        print("Console: g/s/d/0/1/2/q; d prints DMA/DDR debug. t restarts the test. /exit disconnects.")
        try:
            while not ended.is_set():
                key = input().strip()
                if key == "/exit":
                    break
                if len(key) != 1 or key not in "gsd012qtGSDQT":
                    print("Send one of g s d 0 1 2 q t, or /exit")
                    continue
                connection.sendall(key.encode("ascii"))
        except (EOFError, KeyboardInterrupt):
            pass


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="192.168.1.10")
    parser.add_argument("--port", type=int, default=5001)
    parser.add_argument("--timeout", type=float, default=30)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("status")
    commands.add_parser("debug", help="read the saved, sampled DMA/DDR diagnostic record")
    shell = commands.add_parser("console")
    shell.add_argument("--console-port", type=int, default=5000)
    key = commands.add_parser("key")
    key.add_argument("key", choices=list("gsd012qt"))
    commands.add_parser("abort")
    release = commands.add_parser("release", help="explicitly unlock/discard the current frozen capture")
    release.add_argument("capture_id")
    grab = commands.add_parser("capture", help="capture once, wait, then download")
    grab.add_argument("--mib", type=float, default=2044.0)
    grab.add_argument("--wait", type=float, default=90)
    grab.add_argument("--output", "-o", type=Path)
    grab.add_argument("--note", default="")
    grab.add_argument("--no-download", action="store_true")
    fetch = commands.add_parser("download", help="download the existing frozen capture")
    fetch.add_argument("--output", "-o", type=Path, required=True)
    fetch.add_argument("--resume", action="store_true")
    fetch.add_argument("--note", default="")
    args = parser.parse_args(argv)
    if args.command == "console":
        console(args.host, args.console_port, args.timeout)
        return 0
    with Client(args.host, args.port, args.timeout) as client:
        if args.command == "status":
            print(json.dumps(client.request("STATUS"), indent=2))
        elif args.command == "debug":
            print(json.dumps(client.request("DEBUG"), indent=2))
        elif args.command == "key":
            print(client.request(f"KEY {args.key}"))
        elif args.command == "abort":
            print(client.request("ABORT"))
        elif args.command == "release":
            print(client.request(f"RELEASE {args.capture_id}"))
        elif args.command == "capture":
            requested = args.mib * 1048576
            if not requested.is_integer() or not 0 < requested <= MAX_BYTES or requested % PACKET_BYTES:
                parser.error("--mib must be >0, <=2044, and a multiple of 0.03125 MiB")
            client.request(f"CAPTURE {int(requested)}")
            deadline = time.monotonic() + args.wait
            while True:
                info = client.request("STATUS")
                if info["state"] != "capturing":
                    break
                print(f"\rCapturing: {info['received_bytes'] / 1048576:.2f} MiB", end="", file=sys.stderr)
                if time.monotonic() >= deadline:
                    raise TimeoutError("capture wait expired; query status or abort explicitly")
                time.sleep(0.25)
            print(file=sys.stderr)
            validate_capture(info)
            print(f"Capture ready: id={info['capture_id']} bytes={info['bytes']}")
            if not args.no_download:
                output = args.output or Path(f"capture_{info['capture_id']}.bin")
                saved = download(client, output, note=args.note)
                print(f"Saved {output}; SHA256 {saved['sha256']}")
        elif args.command == "download":
            saved = download(client, args.output, resume=args.resume, note=args.note)
            print(f"Saved {args.output}; SHA256 {saved['sha256']}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\nInterrupted; the board keeps the capture. Query status, then download "
              "(use --resume for an existing .part file).", file=sys.stderr)
        sys.exit(130)
    except (OSError, ValueError, KeyError, ProtocolError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(1)
