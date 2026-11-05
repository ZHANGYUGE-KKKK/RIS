"""Analyze only valid recorder rows; never join separate recorder batches."""
import csv
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent

def analyze(paths):
    result = dict(captures=0, samples=0, valid_records=0, iq_records=0,
                  status_low=0, armed_records=0, frame_error_records=0,
                  delay_error_records=0, overflow_records=0,
                  complete_batches=0, counter_discontinuities=0,
                  index_discontinuities=0, counter_examples=[],
                  valid_spacing_histogram={}, frame_histogram={})
    spacing, frames = Counter(), Counter()
    for path in paths:
        with path.open() as f:
            reader = csv.reader(f)
            header, radix = next(reader), next(reader)
            names = [h.rsplit('/', 1)[-1].split('[')[0] for h in header]
            columns = {n: i for i, n in enumerate(names)}
            def get(row, n):
                return int(row[columns[n]], 16)
            groups = {}
            result['captures'] += 1
            for row in reader:
                result['samples'] += 1
                if get(row, 'prefifo_valid_ref') != 1:
                    continue
                result['valid_records'] += 1
                iq = get(row, 'prefifo_official_valid_ref')
                result['iq_records'] += iq
                result['status_low'] += get(row, 'prefifo_official_status_ref') == 0
                result['armed_records'] += get(row, 'prefifo_armed_rx_ref')
                result['frame_error_records'] += get(row, 'prefifo_frame_error_rx_ref')
                result['delay_error_records'] += get(row, 'prefifo_delay_error_rx_ref')
                result['overflow_records'] += get(row, 'prefifo_overflow_rx_ref')
                frames[get(row, 'prefifo_raw_frame_ref')] += 1
                batch = get(row, 'prefifo_batch_ref')
                groups.setdefault(batch, []).append((get(row, 'prefifo_index_ref'),
                    get(row, 'prefifo_rx_edge_counter_ref'), iq))
            for batch, rows in groups.items():
                if [r[0] for r in rows] == list(range(64)):
                    result['complete_batches'] += 1
                last_iq = None
                for i, (index, counter, iq) in enumerate(rows):
                    if i:
                        pi, pc, _ = rows[i-1]
                        delta = (counter - pc) & 0xffffff
                        if index != pi + 1:
                            result['index_discontinuities'] += 1
                        if index == pi + 1 and delta != 1:
                            result['counter_discontinuities'] += 1
                            if len(result['counter_examples']) < 12:
                                result['counter_examples'].append(dict(file=path.name,
                                    batch=batch, index=index, previous=pc, current=counter,
                                    delta=delta))
                    if iq:
                        if last_iq is not None:
                            spacing[index-last_iq] += 1
                        last_iq = index
    result['valid_spacing_histogram'] = dict(sorted(spacing.items()))
    result['frame_histogram'] = dict(sorted(frames.items()))
    return result

if __name__ == '__main__':
    result = analyze(sorted((ROOT/'ila').glob('baseline_*.csv')))
    (ROOT/'baseline_analysis.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result, indent=2))
