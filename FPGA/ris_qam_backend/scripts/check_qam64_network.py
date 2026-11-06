#!/usr/bin/env python3
"""Read-only STATUS from the newly booted RIS; never applies output settings."""
from datetime import datetime
import hashlib,json
from pathlib import Path
import sys
from zoneinfo import ZoneInfo
root=Path(__file__).resolve().parents[1]
host=root.parents[1]/'RIS_CTRL/ris_control_ui_v2'
sys.path.insert(0,str(host))
from ris_client import RisClient
with RisClient('192.168.1.11',7060,timeout=5) as client:
    reply=client.command('STATUS')
if not (reply['ok'] and not reply['errors'] and reply.get('qam64_supported') is True
        and reply.get('qam64_min_event_ticks')==29 and reply.get('qam_clock_hz')==300000000):
    raise SystemExit('New 64QAM firmware capability not confirmed')
image=root/'export_flash/20261105_qam64/BOOT.bin'
record=dict(checked_at=datetime.now(ZoneInfo('Asia/Shanghai')).isoformat(),host='192.168.1.11',port=7060,
            commands=['STATUS'],boot_sha256=hashlib.sha256(image.read_bytes()).hexdigest(),reply=reply)
(root/'reports/flash_qam64_20261105/network_status.json').write_text(json.dumps(record,indent=2,ensure_ascii=False)+'\n')
print('RIS_QAM64_NETWORK_STATUS_PASS: new firmware, QA64 capability, 29-tick events, 300MHz engine; STATUS only')
