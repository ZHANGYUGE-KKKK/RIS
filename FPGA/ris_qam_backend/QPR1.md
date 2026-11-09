# QPR1 independent prefix extension (2026-11-09)

Additive to QAM1 and QA64. AXI100 MHz, player300 MHz and SHCP100 MHz remain unchanged. Offline verification does not imply RF or board acceptance.

Symbol BRAM now has512 words. Ordinary S uploads address0–255. Separate B uploads address256–269 with its own counter and bounds. Each descriptor retains `{count16, first_event16}` and period L. Preflight covers256 S entries plus all B entries before acquiring outputs. First `preamble_rows` B entries repeat once; remaining B entries repeat K times; then formal payload symbols each repeat K times. Loop returns to B[0] or payload[0] if B is empty. Events share one timer and shift/latch pipeline.

| Register | Meaning |
| --- | --- |
| 0x025c | RO ID0x51505231 (QPR1) |
| 0x0260 | RO loaded B count |
| 0x0264 | RO capacity14 |
| 0x0268 | Write next B descriptor |
| 0x026c | Read/write preamble row count0–10 |

START requires B count equal to preamble rows or rows+4. Clear resets both new counts. Upload/configuration freeze through release; STOP, held output, reset and arbitration retain existing semantics.

## TCP protocol

```text
QPBEGIN ticks K L loop mode order
QPCOUNTS frames events formal_bytes preamble_rows phase_count crc
QDATA F offset hex
QDATA E offset hex
QDATA S offset hex
QDATA B offset hex
QDATA P offset hex
QSTART crc
```

Requests retain leading request ID and existing160-byte line bound. `mode` is0 (integer slices) or64 (edge ticks, ticks=1); `order` is actual64 or256 modulation. Old reply `qam_order` retains timing-mode meaning for compatibility. `phase_count` is0 or4. F/E/S/B/P upload is strictly ordered, with empty B skipped; chunks are at most48 bytes and word aligned except P. F has52 bytes/frame, E/S/B areLE32, P contains formal bytes only.

Replies add `qam_prefix_supported`, `qam_max_prefix`, `qam_prefix_count`, `qam_preamble_rows`. The client requires matching capability before a mutating BEGIN.

CRC32 canonical bytes: seven LE32 words `(ticks,K,L,loop,frames,events,formal_bytes)`; optional LE32 `64` for edge mode; four new LE32 words `(0x51505231,actual_order,preamble_rows,phase_count)`; then F,E,S,B,P. Metadata and prefix contents are covered. CRC is not radiated. Legacy QBEGIN/Q64BEGIN/QCOUNTS and CRC remain unchanged.

## Validation

`tests/run_prefix_sim.sh` checks real vendor ODDR and595 models against an independent400-bit source-slot oracle: user263-cycle frame and64QAM/K3/10-row frame, once and loop boundaries. Running the bench with `+CHECK_PREFIX` and no fixture additionally checks dense29-tick edges across B/S/P/wrap, capacity, frozen uploads and invalid prefix descriptors/periods.

Host `test_qam_independent_prefix.py` uses the real C parser/driver, including full4096-byte payload, CRC/metadata corruption and old-device gate. `test_qam_full_chain.py` covers real Tk, worker, TCP client and C model using localhost only.

Build hardware, matching firmware, then a new dated Flash package. Manifests and package verification prevent mixed BIT/XSA/ELF. Build steps do not access a cable or board.
