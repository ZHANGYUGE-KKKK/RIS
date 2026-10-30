#!/usr/bin/env python3
"""Verify this project's unencrypted, three-partition Zynq-7000 BOOT.bin.

Header offsets/checksum convention follow the installed Zynq FSBL's
image_mover.h and image_mover.c. This is an offline content check only.
"""
import hashlib
import json
from pathlib import Path
import struct
import sys
import zipfile


def require(condition, message):
    if not condition:
        raise ValueError(message)


def elf_image(path):
    data = path.read_bytes()
    require(data[:6] == b'\x7fELF\x01\x01', f'{path.name}: expected little-endian ELF32')
    require(struct.unpack_from('<H', data, 18)[0] == 40, 'ELF must target ARM')
    entry, phoff = struct.unpack_from('<II', data, 24)
    phsize, phcount = struct.unpack_from('<HH', data, 42)
    segments = []
    for i in range(phcount):
        kind, offset, _, address, filesz, memsz, _, _ = struct.unpack_from('<8I', data, phoff+i*phsize)
        if kind == 1 and filesz:
            require(filesz <= memsz and offset+filesz <= len(data), 'Invalid ELF segment')
            segments.append((address, data[offset:offset+filesz]))
    require(bool(segments), 'ELF has no loadable data')
    start = min(a for a, _ in segments)
    end = max(a+len(b) for a, b in segments)
    require(end-start < 32*1024*1024, 'Unexpected ELF address span')
    image = bytearray(end-start)
    for address, content in segments:
        image[address-start:address-start+len(content)] = content
    return start, entry, bytes(image)


def bit_image(path):
    data = path.read_bytes()
    pos = 2 + int.from_bytes(data[:2], 'big')
    require(data[pos:pos+2] == b'\0\1', 'Invalid BIT header')
    pos += 2
    for tag in b'abcde':
        require(data[pos] == tag, 'Unexpected BIT header field')
        pos += 1
        size_bytes = 4 if tag == ord('e') else 2
        length = int.from_bytes(data[pos:pos+size_bytes], 'big')
        pos += size_bytes
        if tag == ord('e'):
            payload = data[pos:pos+length]
            require(pos+length == len(data) and length % 4 == 0, 'Invalid BIT payload length')
            # Bootgen swaps configuration words and pads the PCAP partition
            # to 64 bytes with configuration NOP words (0x20000000).
            swapped = b''.join(payload[i:i+4][::-1] for i in range(0, length, 4))
            return swapped + b'\x00\x00\x00\x20' * ((-length % 64)//4)
        pos += length
    raise ValueError('Missing BIT payload')


def verify(package):
    data = (package/'BOOT.bin').read_bytes()
    require(len(data) < 32*1024*1024, 'Image exceeds 32 MiB dual-parallel QSPI capacity')
    require(struct.unpack_from('<II', data, 0x20) == (0xaa995566, 0x584c4e58), 'Bad boot identification')
    require(sum(struct.unpack_from('<11I', data, 0x20)) & 0xffffffff == 0xffffffff, 'Bad boot-header checksum')
    iht, pht = struct.unpack_from('<II', data, 0x98)
    require(struct.unpack_from('<I', data, iht+4)[0] == 3, 'Expected three image headers')
    require(struct.unpack_from('<I', data, iht+8)[0]*4 == pht, 'Partition-table pointer mismatch')
    inputs = [('fsbl.elf', 0x10), ('ris_ctrl_unit.bit', 0x20), ('ris_all_io.elf', 0x10)]
    partitions = []
    prior_end = pht + len(inputs)*64
    for i, (name, attribute) in enumerate(inputs):
        words = struct.unpack_from('<16I', data, pht+i*64)
        require(sum(words) & 0xffffffff == 0xffffffff, f'{name}: bad partition-header checksum')
        length, load, entry, offset, attrs = words[2]*4, words[3], words[4], words[5]*4, words[6]
        require(words[0] == words[1] == words[2], 'Unexpected encrypted/padded partition')
        require(offset >= prior_end and offset+length <= len(data), 'Partition overlap or out-of-bounds data')
        require(attrs == attribute, f'{name}: unexpected destination attributes')
        if name.endswith('.elf'):
            expected_load, expected_entry, content = elf_image(package/name)
            require((load, entry) == (expected_load, expected_entry), f'{name}: wrong load/entry address')
        else:
            content = bit_image(package/name)
        require(length == len(content), f'{name}: wrong partition length')
        require(data[offset:offset+length] == content, f'{name}: embedded content differs from input')
        if i == 0:
            require(struct.unpack_from('<I', data, 0x30)[0] == offset, 'FSBL boot offset mismatch')
            require(struct.unpack_from('<I', data, 0x34)[0] == length, 'FSBL boot length mismatch')
        partitions.append(dict(name=name, flash_offset=hex(offset), bytes=length,
                               load_address=hex(load), entry_address=hex(entry), attributes=hex(attrs),
                               content_matches_input=True))
        prior_end = offset+length
    with zipfile.ZipFile(package/'ris_ctrl_unit.xsa') as archive:
        bits = [name for name in archive.namelist() if name.endswith('.bit')]
        require(len(bits) == 1, 'Expected exactly one BIT in XSA')
        require(archive.read(bits[0]) == (package/'ris_ctrl_unit.bit').read_bytes(), 'BIT/XSA differ')
        require(archive.read('ps7_init.tcl') == (package/'ps7_init.tcl').read_bytes(), 'PS initialization/XSA differ')
    result = dict(board='ZC706 / XC7Z045', architecture='zynq', flash_type='qspi-x8-dual_parallel',
                flash_program_offset='0x0', flash_capacity_bytes=32*1024*1024, image_bytes=len(data),
                boot_header_checksum_valid=True, partition_header_checksums_valid=True,
                flash_partitions_nonoverlapping=True, all_partition_contents_match_inputs=True,
                bit_matches_xsa=True, partitions=partitions, flash_programmed=False,
                hardware_boot_tested=False, boot_sha256=hashlib.sha256(data).hexdigest())
    # Preserve a separately recorded hardware event only for this exact image.
    # Rebuilding/verifying an image never performs hardware access itself.
    record_path = package/'hardware_programming.json'
    if record_path.is_file():
        record = json.loads(record_path.read_text())
        if (record.get('boot_sha256') == result['boot_sha256'] and
                record.get('image_bytes') == len(data) and
                record.get('direct_full_byte_compare') == 'PASS' and
                record.get('independent_program_flash_verify') == 'PASS'):
            result['flash_programmed'] = True
            result['hardware_boot_tested'] = record.get('cold_boot_test') == 'PASS'
            result['hardware_programming_record'] = record_path.name
    return result


if __name__ == '__main__':
    package = Path(sys.argv[1] if len(sys.argv) > 1 else '.').resolve()
    result = verify(package)
    (package/'validation.json').write_text(json.dumps(result, indent=2)+'\n')
    print(f"PASS: {result['image_bytes']} bytes; all 3 partition contents, headers, addresses, BIT/XSA verified")
