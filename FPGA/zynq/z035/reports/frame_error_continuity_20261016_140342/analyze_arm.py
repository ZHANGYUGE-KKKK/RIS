import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parent
FIELDS = '''magic mode packets gate stage done result restore_result saved_bist
saved_observe saved_mask reset_result gpio_result dma_init_result prepare_result
start_result wait_result pn_result start_attempts pre_flags post_flags dma_status
bd_status completed_packets received_bytes driver_state samples_before samples_after
edges_before edges_after pn_status_0 pn_status_1 pn_status_2 pn_status_3 written_tuples
prefix_tuples malformed_components period_errors minimum_0 minimum_1 minimum_2 minimum_3
maximum_0 maximum_1 maximum_2 maximum_3 restored_bist restored_observe restored_mask'''.split()
SIGNED = {f for f in FIELDS if f.endswith('_result') or f.startswith('minimum_') or f.startswith('maximum_')}

def decode(path):
    words = struct.unpack('<64I', path.read_bytes())
    r = dict(zip(FIELDS, words))
    for f in SIGNED:
        if r[f] & 0x80000000: r[f] -= 1 << 32
    r['sample_delta'] = (r['samples_after']-r['samples_before']) & 0xffffff
    r['edge_delta'] = (r['edges_after']-r['edges_before']) & 0xffffff
    r['mode_name'] = {0:'ordinary_RF',1:'RX_digital_tone_Fs_div_16',2:'RX_PRBS'}[r['mode']]
    r['accepted_DMA_window'] = r['start_result'] == 0 and r['wait_result'] == 0 and r['completed_packets'] == r['packets']
    r['frame_error_latched'] = bool(r['post_flags'] & 0x10)
    r['continuity_verdict'] = 'NOT_VERIFIED' if not r['accepted_DMA_window'] else ('FAIL' if r['malformed_components'] or (r['mode']==1 and r['period_errors']) else 'PERIOD_TEST_ONLY')
    return r

if __name__ == '__main__':
    trials=[]
    for path in sorted((ROOT/'arm').glob('trial_*_restored.bin')):
        r=decode(path); r['file']=path.name; trials.append(r)
    (ROOT/'arm_analysis.json').write_text(json.dumps(trials,indent=2)+'\n')
    for r in trials:
        print(r['file'],r['mode_name'],'start',r['start_result'],'wait',r['wait_result'],
              'flags',hex(r['post_flags']),'packets',r['completed_packets'],
              'written',r['written_tuples'],'period_errors',r['period_errors'],
              'PN',r['pn_result'],'restore',r['restore_result'])
