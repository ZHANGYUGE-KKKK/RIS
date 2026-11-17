"""Real Tk, mock board: export/load/select are offline; one output gate."""
from copy import deepcopy
from pathlib import Path
import json
import tkinter as tk
from tkinter import ttk
import unittest
from unittest.mock import patch
import test_console_gui as baseline
from ris_actions import OutputAction
from ris_demo_gui import DemoPage
from ris_presets import save_preset,load_preset
from ris_qam256 import ORIENTATIONS

class DemoGuiTests(unittest.TestCase):
    setUp=baseline.ConsoleTests.setUp
    tearDown=baseline.ConsoleTests.tearDown
    wait=baseline.ConsoleTests.wait
    settle=baseline.ConsoleTests.settle
    connect=baseline.ConsoleTests.connect
    apply=baseline.ConsoleTests.apply
    writes=baseline.ConsoleTests.writes
    playlist=baseline.ConsoleTests.playlist

    def export_board(self,mode,name=None):
        self.app.show_page('board');self.app.board_mode.set(mode)
        path=self.directory/(name or mode+'.json')
        self.assertTrue(self.app.export_config(path),self.app.notice.get())
        return path

    def test_ten_rows_load_select_only_and_total_gate_applies_chosen_snapshot(self):
        paths=[self.export_board('all1','一号.json'),self.export_board('all0','二号.json')]
        p=self.app.demo_page;self.app.show_page('demo');self.root.update()
        self.assertEqual(len(p.select_buttons),10)
        self.assertEqual([b.cget('text') for b in p.load_buttons],['请加载预设']*10)
        for i in range(10):
            self.assertTrue(p.load(i,paths[i%2]));self.assertEqual(p.load_buttons[i].cget('text'),paths[i%2].name)
        self.assertIsNone(p.selected);self.assertFalse(self.app.apply_current())
        self.assertEqual(baseline.Board.instances,0)
        p.select_buttons[8].invoke();self.root.update()
        self.assertEqual(p.selected,8);self.assertIn('一号.json',self.app.pending_text.get())
        self.assertEqual(self.writes(),[])
        self.connect();self.assertEqual(self.writes(),[])
        self.app.apply_button.invoke();self.wait(lambda:not self.app.busy)
        self.assertEqual(self.writes(),['ALL 1'])
        p.select_buttons[9].invoke();self.root.update()
        self.assertEqual(self.writes(),['ALL 1']);self.assertIn('全1',self.app.status_title.get())
        self.apply();self.assertEqual(self.writes(),['ALL 1','ALL 0'])
        self.assertEqual(self.app.content.pack_slaves(),[self.app.frames['demo']])

    def test_invalid_reload_preserves_row_and_snapshot_survives_external_changes(self):
        path=self.export_board('all1');p=self.app.demo_page
        self.assertTrue(p.load(0,path));p.select(0);self.app.show_page('demo')
        path.write_text('{broken')
        self.assertFalse(p.load(0,path));self.assertEqual(p.selected,0)
        self.assertEqual(p.prepare_action().payload,'ALL 1')
        save_preset(path,OutputAction('command','ALL 0','全0'))
        self.assertEqual(p.prepare_action().payload,'ALL 1')
        self.assertTrue(p.load(0,path));self.assertIsNone(p.selected)
        with self.assertRaises(ValueError):p.prepare_action()
        p.select(0);self.assertEqual(p.prepare_action().payload,'ALL 0')
        self.assertEqual(self.writes(),[])

    def test_cache_restores_ten_rows_without_original_files_or_auto_selection(self):
        path=self.export_board('all1');p=self.app.demo_page
        for i in range(10):self.assertTrue(p.load(i,path))
        p.select(9);path.unlink()
        frame=ttk.Frame(self.root)
        restored=DemoPage(self.app,frame,p.storage.parent)
        self.assertEqual(sum(entry is not None for entry in restored.entries),10)
        self.assertIsNone(restored.selected)
        self.assertFalse(restored.stop_selected)
        restored.select(4);self.assertEqual(restored.prepare_action().payload,'ALL 1')
        self.assertEqual(self.writes(),[]);self.assertEqual(baseline.Board.instances,0)
        frame.destroy()

    def test_load_dialog_and_global_export_button_use_same_json_format(self):
        path=self.directory/'通过按钮导出.json'
        self.app.board_mode.set('all1');self.root.update()
        with patch('ris_gui.filedialog.asksaveasfilename',return_value=str(path)) as dialog:
            self.app.export_config_button.invoke();dialog.assert_called_once()
        document,action=load_preset(path)
        self.assertEqual(action.payload,'ALL 1')
        self.app.show_page('demo')
        with patch('ris_demo_gui.filedialog.askopenfilename',return_value=str(path)) as dialog:
            self.app.demo_page.load_buttons[2].invoke();dialog.assert_called_once()
        self.assertEqual(self.app.demo_page.load_buttons[2].cget('text'),path.name)
        self.assertIsNone(self.app.demo_page.selected)
        self.assertEqual(self.writes(),[])

    def test_export_all_existing_feature_actions_is_offline(self):
        exported=[]
        def save(label):
            path=self.directory/(label+'.json');expected=self.app._prepare_action()
            self.assertTrue(self.app.export_config(path),self.app.notice.get())
            _,actual=load_preset(path);self.assertEqual(actual.kind,expected.kind)
            self.assertEqual(actual.payload,expected.payload)
            exported.append(path)
        for mode in ('stop','all0','all1','blink','fast'):
            self.app.show_page('board');self.app.board_mode.set(mode);save(mode)
        for group in (False,True):
            self.app.chip.set('17');self.app.hex_value.set('5A');self.app.apply_byte(group);save('group' if group else 'chip')
        self.app.manual.select_cell(1,1);self.app.manual.control(1);save('cell')
        self.app.open_mapping();self.app.mapping_page.test_channel();save('mapping_probe')
        self.app.show_settings('输出设置')
        for mode in ('enable','disable'):
            self.app.settings_mode.set(mode);save(mode)
        self.app.show_page('mt');self.app.fast_value.set('100');self.app.fast_unit.set('k');save('uniform_square')
        mt=self.directory/'table.txt';mt.write_text('(25,0);\n(75,40);')
        self.assertTrue(self.app.mt_controls.load(mt));save('uniform_mt')
        self.app.mt_controls.loop.set(False);save('uniform_mt_once')
        self.playlist('pingpong');save('playlist')
        self.app.pattern_page.apply_draft();save('static_pattern')
        self.app.qam_orientation.set(ORIENTATIONS['identity']);self.app.qam_state1.set('驱动高');self.app.qam_confirmed.set(True)
        for order in (64,256):
            self.app.open_qam(order);p=self.app.active_qam_page();self.assertTrue(p.load(p.default_path))
            save('qam'+str(order));p.action.set('static');save('qam_static'+str(order))
        self.assertEqual(len(exported),20)
        self.assertEqual(self.writes(),[]);self.assertEqual(baseline.Board.instances,0)

    def test_demo_playlist_keeps_schedule_when_loading_and_switches_on_total_only(self):
        self.playlist('loop');self.app.pattern_page.library.playlist[0]['dwell_ms']=1000
        self.app.pattern_page.library.playlist[1]['dwell_ms']=1000
        path=self.directory/'playlist.json';self.assertTrue(self.app.export_config(path))
        other=self.export_board('all1');p=self.app.demo_page
        self.assertTrue(p.load(0,path));self.assertTrue(p.load(1,other));self.app.show_page('demo');p.select(0)
        self.connect();self.apply()
        self.assertTrue(self.app.pattern_page.player.active)
        writes=list(self.writes());p.select(1);self.assertTrue(p.load(2,other));self.root.update()
        self.assertTrue(self.app.pattern_page.player.active);self.assertEqual(writes,self.writes())
        self.apply();self.assertFalse(self.app.pattern_page.player.active);self.assertEqual(self.writes()[-1],'ALL 1')
        self.settle(.1);self.assertEqual(self.writes()[-1],'ALL 1')

    def test_demo_selection_during_inflight_command_does_not_replace_it(self):
        p=self.app.demo_page;one=self.export_board('all1');zero=self.export_board('all0')
        p.load(0,one);p.load(1,zero);self.app.show_page('demo');p.select(0);self.connect()
        baseline.Board.gate_op='ALL';self.app.apply_current();self.wait(baseline.Board.blocked.is_set)
        p.select(1);self.root.update();self.assertFalse(self.app.apply_current())
        baseline.Board.release.set();self.wait(lambda:not self.app.busy)
        self.assertEqual(self.app.applied_action.payload,'ALL 1');self.assertEqual(p.prepare_action().payload,'ALL 0')
        self.assertEqual(self.writes(),['ALL 1'])

    def test_stop_is_staged_and_demo_rows_fit_small_window(self):
        self.root.deiconify();self.root.geometry('1180x760');self.app.show_page('demo');self.root.update()
        p=self.app.demo_page
        path=self.directory/'布局测试.json'
        save_preset(path,OutputAction('command','ALL 1','全板全1 · 静态保持'))
        self.assertTrue(p.load(0,path));p.select(0);self.root.update()
        last=p.load_buttons[-1]
        self.assertGreater(last.winfo_height(),20)
        bottom=last.winfo_rooty()+last.winfo_height()-self.root.winfo_rooty()
        self.assertLessEqual(bottom,self.root.winfo_height())
        self.assertLessEqual(last.winfo_rooty()+last.winfo_height(),p.canvas.winfo_rooty()+p.canvas.winfo_height())
        p.canvas.yview_moveto(1);self.root.update()
        self.assertLessEqual(last.winfo_rooty()+last.winfo_height(),p.canvas.winfo_rooty()+p.canvas.winfo_height())
        p.stage_stop();self.assertEqual(p.prepare_action().payload,'STOP');self.assertEqual(self.writes(),[])

if __name__=='__main__':unittest.main()
