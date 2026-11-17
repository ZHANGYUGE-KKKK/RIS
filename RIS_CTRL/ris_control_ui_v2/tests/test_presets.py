"""Portable presets preserve outputs without external source files or a board."""
from copy import deepcopy
from dataclasses import replace
from decimal import Decimal
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch

BASE=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(BASE))
from ris_actions import OutputAction,PlaybackStep,PlaylistPlan
from ris_mapping import RisMapping
from ris_mt import compile_mt,parse_mt
from ris_presets import document_for_action,action_from_document,load_preset,save_preset,read_json,MAX_FILE_BYTES
from ris_qam256 import QamCodebook
from ris_qam_transport import make_plan

class PresetTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.mapping=RisMapping.load(BASE/'mappings/ris_mapping.json')
        cls.qam={}
        for order in (64,256):
            book=QamCodebook.load(BASE.parents[1]/f'QAM_RULES/{order}QAM/ris_{order}qam_64slice_codebook')
            cls.qam[order]=make_plan(book,cls.mapping,0,'identity',True,1,True,bytes(range(order)),
                preamble_rows=parse_mt('(25,0);\n(50,0);\n(75,0);'),phase_compensation=True,
                pwm_hz=120000 if order==256 else 160000,independent_prefix=True)
    def roundtrip(self,action):
        document=document_for_action(action,'测试')
        return document,action_from_document(document)
    def test_every_supported_command_roundtrips_without_callbacks(self):
        for command in ('STOP','ALL 0','ALL 1','OE 0','OE 1','BLINK 500','FASTTICKS 30','FASTTICKS 150000000',
                        'CHIP 49 A5','GROUP 9 FF','BIT 49 7 1','FRAME '+('f1'*50)):
            with self.subTest(command=command):
                _,actual=self.roundtrip(OutputAction('command',command,'配置',callback=lambda:None,tag='qam_static'))
                self.assertEqual(actual.payload,command.upper())
                self.assertIsNone(actual.callback)
                self.assertEqual(actual.tag,'qam_static')
    def test_mt_reconstructs_exact_segments_frequency_repeat_and_checksum(self):
        for loop in (False,True):
            plan=compile_mt(parse_mt('(25,0);\n(80,40);\n(0,0);\n(100,0);'),'137.5','k',loop)
            _,restored=self.roundtrip(OutputAction('mt',plan,'统一MT'))
            self.assertEqual(restored.payload,plan)
            self.assertEqual(list(restored.payload.commands()),list(plan.commands()))
    def test_playlists_keep_all_modes_frames_order_and_dwells(self):
        for mode in ('once','loop','pingpong','random'):
            plan=PlaylistPlan((PlaybackStep('图案A',bytes(50),137),PlaybackStep('图案B',b'\xff'*50,251)),mode)
            _,actual=self.roundtrip(OutputAction('playlist',plan,'播放列表'))
            self.assertEqual(plan,actual.payload)
    def test_both_qam_orders_preserve_complete_wire_commands_and_crc(self):
        for order,plan in self.qam.items():
            with self.subTest(order=order):
                document,restored=self.roundtrip(OutputAction('qam',plan,'QAM循环',mapping_document=self.mapping.document(),tag='qam_play'))
                self.assertEqual(restored.payload,plan)
                self.assertEqual(list(plan.commands()),list(restored.payload.commands()))
                self.assertEqual(restored.mapping_document,self.mapping.document())
                self.assertEqual(restored.payload.frame_cycles,263 if order==256 else 71)
                with tempfile.TemporaryDirectory() as temp:
                    path=Path(temp)/'自包含预设.json'
                    save_preset(path,restored)
                    with patch.object(QamCodebook,'load',side_effect=AssertionError('must not reopen a codebook')):
                        _,loaded=load_preset(path)
                    self.assertEqual(loaded.payload.crc,plan.crc)
                    self.assertLess(path.stat().st_size,MAX_FILE_BYTES)
    def test_plain_qam_legacy_timing_and_constant_preamble_levels(self):
        book=QamCodebook.load(BASE.parents[1]/'QAM_RULES/256QAM/ris_256qam_256slice_codebook_0deg.zip')
        for rows,phase in (((),False),((('0','0'),('100','0')),True)):
            plan=make_plan(book,self.mapping,0,'identity',False,3,False,b'\x55\xaa',preamble_rows=rows,
                          phase_compensation=phase,pwm_hz=100,independent_prefix=True)
            _,restored=self.roundtrip(OutputAction('qam',plan,'QAM'))
            self.assertEqual(restored.payload,plan)
    def test_bad_commands_unknown_functions_versions_and_mt_rejected(self):
        base=document_for_action(OutputAction('command','ALL 1','全1'))
        for bad in ('STATUS','QBEGIN 60 3 256 1','ALL 2','BIT 50 0 1','GROUP 10 FF','CHIP 0 0000',
                    'FASTTICKS 29','BLINK 99','ALL 1\nSTOP','FRAME 00'):
            doc=deepcopy(base);doc['action']['payload']['command']=bad
            with self.subTest(command=bad),self.assertRaises(ValueError):action_from_document(doc)
        for version in (True,2,'1'):
            doc=deepcopy(base);doc['version']=version
            with self.assertRaises(ValueError):action_from_document(doc)
        doc=deepcopy(base);doc['action']['kind']='shell'
        with self.assertRaises(ValueError):action_from_document(doc)
        doc=deepcopy(base);doc['action'].update(kind='mt',payload={'rows':[['NaN','0']],'requested_hz':'100','loop':True})
        with self.assertRaises(ValueError):action_from_document(doc)
    def test_corrupt_qam_crc_descriptor_duration_and_phase_rejected(self):
        plan=self.qam[256];doc=document_for_action(OutputAction('qam',plan,'QAM'))
        for target,value in (('crc32',0),('slot_ticks',2),('logical_payload','00'),('logical_slots',256),('phase_symbols','00042420')):
            corrupted=deepcopy(doc);corrupted['action']['payload'][target]=value
            with self.subTest(target=target),self.assertRaises(ValueError):action_from_document(corrupted)
        corrupted=deepcopy(doc)
        corrupted['action']['payload']['blocks']['S']=struct.pack('<HH',plan.events,1).hex()+plan.blocks[2][4:].hex()
        with self.assertRaisesRegex(ValueError,'描述'):action_from_document(corrupted)
        corrupted=deepcopy(doc);corrupted['action']['payload']['preamble']['rows'][0][0]='50'
        with self.assertRaisesRegex(ValueError,'前导码'):action_from_document(corrupted)
    def test_export_size_limit_matches_utf8_file_load_limit(self):
        plan=PlaylistPlan((PlaybackStep('图'*1024,bytes(50),100),)*1024,'once')
        with tempfile.TemporaryDirectory() as temp:
            path=Path(temp)/'too_large.json'
            with self.assertRaisesRegex(ValueError,'2 MiB'):
                save_preset(path,OutputAction('playlist',plan,'播放列表'))
            self.assertFalse(path.exists())

    def test_file_bounds_duplicate_keys_nonfinite_and_bad_json(self):
        with tempfile.TemporaryDirectory() as temp:
            path=Path(temp)/'preset.json'
            for data in (b'{"version":1,"version":1}',b'{"x":NaN}',b'{broken',b' '* (MAX_FILE_BYTES+1)):
                path.write_bytes(data)
                with self.assertRaises(ValueError):load_preset(path)
            with self.assertRaises(ValueError):save_preset(path.with_suffix('.txt'),OutputAction('command','STOP','停止'))

if __name__=='__main__':unittest.main()
