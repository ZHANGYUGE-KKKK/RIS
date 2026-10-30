"""Embedded spatial pattern editor, persistent library and software sequencer."""
from ris_frequency import active_frequency
from datetime import datetime
from pathlib import Path
import shutil
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

from ris_pattern_player import PatternPlayer
from ris_patterns import MODES, Pattern, PatternLibrary, compile_frame, dwell_ms, from_image
from ris_topology import TopologyView
from ris_actions import OutputAction, PlaybackStep, PlaylistPlan


class PatternPage:
    def __init__(self, app, mapping, parent, storage_dir=None):
        self.app, self.mapping = app, mapping
        self.alive = True
        self.storage_dir = Path(storage_dir) if storage_dir else Path(__file__).resolve().parent / "patterns"
        self.path = self.storage_dir / "library.json"
        self.library = PatternLibrary.defaults()
        load_error = ""
        if self.path.exists():
            try:
                self.library = PatternLibrary.load(self.path)
            except (OSError, ValueError, TypeError) as error:
                load_error = f"原图案库未能载入，文件保留：{error}"
        self.pattern = Pattern()
        self.draft_id = None
        self.saved_rows, self.saved_name = self.pattern.rows, "新图案"
        self.history = []
        self.drag_cells = None
        self.mapping_document = None
        self.mapping_error = ""
        self.play_mapping = None
        self.play_keys = []
        self.output_action = "draft"
        self.name = tk.StringVar(value="新图案")
        self.row, self.column = tk.StringVar(value="1"), tk.StringVar(value="1")
        self.brush = tk.StringVar(value="1")
        self.duration = tk.StringVar(value="1000")
        self.mode = tk.StringVar(value=MODES[self.library.mode])
        self.summary = tk.StringVar()
        self.notice = tk.StringVar(value=load_error or "本页只配置；点击右上角“下发指令”应用。运行中可以继续编辑下一次的配置。")
        self.play_status = tk.StringVar(value="未播放 · 停止后保持最后图案")
        self.edit_controls = []
        self.player = PatternPlayer(app.root, self._send_play_frame, lambda: app.connected,
                                    lambda: app.busy, self._player_event)
        self.frame = ttk.Frame(parent, padding=(0, 8, 0, 0))
        self.frame.pack(fill="both", expand=True)
        self._build()
        self.name.trace_add("write", lambda *_: self.update_summary())
        self.refresh_lists()
        if self.library.patterns:
            self._activate(next(iter(self.library.patterns)))
        self.update_state()

    def _button(self, parent, text, command, edit=True):
        button = ttk.Button(parent, text=text, style="Mapping.TButton", command=command)
        if edit:
            self.edit_controls.append(button)
        return button

    def _build(self):
        top = ttk.Frame(self.frame)
        top.pack(fill="x")
        ttk.Label(top, text="图案名").pack(side="left")
        name = ttk.Entry(top, textvariable=self.name, width=22)
        name.pack(side="left", padx=5)
        self.edit_controls.append(name)
        for label, callback in (("新建", self.new), ("保存图案", self.save_pattern),
                                 ("删除图案", self.delete_pattern), ("读取板端镜像", self.read_board)):
            self._button(top, label, callback).pack(side="left", padx=3)
        self._button(top, "导出图案库", self.export_library).pack(side="right", padx=3)
        self._button(top, "导入图案库", self.import_library).pack(side="right", padx=3)

        tools = ttk.Frame(self.frame)
        tools.pack(fill="x", pady=6)
        for label, variable, axis in (("行", self.row, "row"), ("列", self.column, "column")):
            ttk.Label(tools, text=label).pack(side="left")
            spin = ttk.Spinbox(tools, from_=1, to=20, textvariable=variable, width=4, command=self.draw)
            spin.pack(side="left", padx=4)
            spin.bind("<Return>", lambda _: self.draw())
            self.edit_controls.append(spin)
            for value in (0, 1):
                self._button(tools, f"整{label} {value}", lambda a=axis, v=value: self.set_line(a, v)).pack(side="left", padx=2)
        for label, callback in (("全0", lambda: self.edit(Pattern())),
                                 ("全1", lambda: self.edit(Pattern(["1" * 20] * 20))),
                                 ("反相", lambda: self.edit(self.pattern.inverted())), ("撤销", self.undo)):
            self._button(tools, label, callback).pack(side="left", padx=3)
        status = ttk.Frame(self.frame)
        status.pack(fill="x")
        ttk.Label(status, textvariable=self.summary, foreground="#315b80").pack(side="left")
        for text, value in (("画笔1", "1"), ("画笔0", "0"), ("翻转", "toggle")):
            radio = ttk.Radiobutton(status, text=text, variable=self.brush, value=value)
            radio.pack(side="left", padx=5)
            self.edit_controls.append(radio)
        self.apply_button = self._button(status, "选择编辑图案", self.apply_draft, edit=False)
        self.apply_button.pack(side="right", padx=3)
        self._button(status, "FPC映射设置", self.app.open_mapping, edit=False).pack(side="right", padx=3)
        footer = ttk.Frame(self.frame)
        footer.pack(side="bottom", fill="x", pady=(5, 0))
        ttk.Label(footer, textvariable=self.notice, foreground="#245c85", wraplength=1320).pack(anchor="w")
        ttk.Label(footer, text="图中0/1为编辑预览。总按钮应用当前配置；播放使用下发时的图案、顺序和时长，后续编辑经再次下发生效。",
                  wraplength=1320).pack(anchor="w", pady=(3, 0))

        panes = ttk.Panedwindow(self.frame, orient="horizontal")
        panes.pack(fill="both", expand=True, pady=(6, 0))
        visual = ttk.Frame(panes)
        panes.add(visual, weight=4)
        self.canvas = tk.Canvas(visual, background="#f6f8fb", highlightthickness=0)
        self.topology = TopologyView(self.mapping, self.canvas)
        scroll = ttk.Scrollbar(visual, orient="vertical", command=self.canvas.yview)
        scroll.pack(side="right", fill="y")
        self.canvas.configure(yscrollcommand=scroll.set)
        self.canvas.pack(fill="both", expand=True)
        self.canvas.bind("<Configure>", lambda _: self.draw())
        self.canvas.bind("<Button-1>", self.paint_start)
        self.canvas.bind("<B1-Motion>", self.paint_drag)
        self.canvas.bind("<ButtonRelease-1>", lambda _: setattr(self, "drag_cells", None))

        side = ttk.Frame(panes, width=355, padding=(8, 0, 0, 0))
        panes.add(side, weight=0)
        self.tabs = tabs = ttk.Notebook(side, width=345)
        tabs.pack(fill="both", expand=True)
        library_tab, playlist_tab = ttk.Frame(tabs), ttk.Frame(tabs)
        tabs.add(library_tab, text="图案库")
        tabs.add(playlist_tab, text="切换列表")
        def scrolling(parent):
            canvas = tk.Canvas(parent, width=330, highlightthickness=0)
            scroll = ttk.Scrollbar(parent, orient="vertical", command=canvas.yview)
            scroll.pack(side="right", fill="y")
            canvas.configure(yscrollcommand=scroll.set)
            canvas.pack(side="left", fill="both", expand=True)
            content = ttk.Frame(canvas, padding=5)
            item = canvas.create_window(0, 0, window=content, anchor="nw")
            content.bind("<Configure>", lambda _: canvas.configure(scrollregion=canvas.bbox("all")))
            canvas.bind("<Configure>", lambda event: canvas.itemconfigure(item, width=event.width))
            return content
        library, playlist = scrolling(library_tab), scrolling(playlist_tab)
        ttk.Label(library, text="选择图案可预览；保存后可加入播放列表。", wraplength=320).pack(anchor="w", pady=5)
        self.templates = ttk.Treeview(library, columns=("name", "ones"), show="headings", height=9, selectmode="browse")
        for key, title, width in (("name", "图案", 205), ("ones", "高电平数", 75)):
            self.templates.heading(key, text=title)
            self.templates.column(key, width=width, minwidth=60)
        self.templates.pack(fill="both", expand=True)
        self.templates.bind("<<TreeviewSelect>>", self.select_template)
        self._button(library, "加入切换列表（可重复添加）", self.add_step).pack(fill="x", pady=6)
        ttk.Label(library, text="图案和列表保存在此副本中。\n可导出图案库，备份空间图案、播放顺序和各项时长。", wraplength=320).pack(anchor="w")

        self.steps = ttk.Treeview(playlist, columns=("number", "name", "time"), show="headings", height=6, selectmode="browse")
        for key, title, width in (("number", "序号", 45), ("name", "图案", 160), ("time", "停留ms", 85)):
            self.steps.heading(key, text=title)
            self.steps.column(key, width=width, minwidth=40)
        self.steps.pack(fill="both", expand=True)
        self.steps.bind("<<TreeviewSelect>>", self.select_step)
        self.steps.bind("<Double-1>", lambda _: self.preview_step())
        order = ttk.Frame(playlist)
        order.pack(fill="x", pady=4)
        for text, callback in (("上移", lambda: self.move_step(-1)), ("下移", lambda: self.move_step(1)), ("移除", self.remove_step), ("预览", self.preview_step)):
            button = self._button(order, text, callback)
            button.configure(width=5)
            button.pack(side="left", padx=2)
        timing = ttk.Frame(playlist)
        timing.pack(fill="x")
        ttk.Label(timing, text="停留ms").pack(side="left")
        duration = ttk.Spinbox(timing, from_=100, to=3600000, increment=100, textvariable=self.duration, width=8)
        duration.pack(side="left", padx=4)
        self.edit_controls.append(duration)
        self._button(timing, "设置所选项", self.set_duration).pack(side="left")
        self._button(playlist, "所有项使用此时长", lambda: self.set_duration(all_steps=True)).pack(fill="x", pady=4)
        self.mode_box = ttk.Combobox(playlist, textvariable=self.mode, values=list(MODES.values()), state="readonly")
        self.mode_box.pack(fill="x", pady=4)
        self.mode_box.bind("<<ComboboxSelected>>", self.set_mode)
        play = ttk.Frame(playlist)
        play.pack(fill="x")
        self.start_button = self._button(play, "选择列表播放", self.start, edit=False)
        self.start_button.pack(side="left", fill="x", expand=True)
        self.stop_button = self._button(play, "选择停止 / 保持", self.stage_stop, edit=False)
        self.stop_button.pack(side="left", fill="x", expand=True, padx=(5, 0))
        manual = ttk.Frame(playlist)
        manual.pack(fill="x", pady=4)
        self.previous_button = self._button(manual, "选择上一播放项", lambda: self.manual_step(-1), edit=False)
        self.previous_button.pack(side="left")
        self.next_button = self._button(manual, "选择下一播放项", lambda: self.manual_step(1), edit=False)
        self.next_button.pack(side="left", padx=4)
        self.step_button = self._button(playlist, "选择此播放项", self.apply_step, edit=False)
        self.step_button.pack(fill="x")
        ttk.Label(playlist, textvariable=self.play_status, foreground="#245c85", wraplength=320).pack(anchor="w", pady=6)

    def dirty(self):
        return self.pattern.rows != self.saved_rows or self.name.get().strip() != self.saved_name

    def may_discard(self):
        if not self.dirty():
            return True
        choice = messagebox.askyesnocancel("保存图案", "当前编辑图案尚未保存，是否先保存？", parent=self.frame)
        return False if choice is None else (self.save_pattern() if choice else True)

    def update_summary(self):
        self.summary.set(f"编辑预览 · {self.pattern.count()}/400 路为1" +
                         (" · 未保存" if self.dirty() or self.draft_id is None else " · 已保存") +
                         (" · 需完整FPC映射才能下发" if self.mapping_error else ""))
        self.app.refresh_pending()

    def _activate(self, key):
        value = self.library.patterns[key]
        self.draft_id = key
        self.pattern = Pattern(value["rows"])
        self.saved_rows, self.saved_name = self.pattern.rows, value["name"]
        self.name.set(value["name"])
        self.history.clear()
        self.templates.selection_set(key)
        self.templates.see(key)
        self.draw()

    def select_template(self, _event=None):
        chosen = self.templates.selection()
        if not chosen or chosen[0] == self.draft_id:
            return
        if not self.may_discard():
            if self.draft_id in self.library.patterns:
                self.templates.selection_set(self.draft_id)
            return
        self._activate(chosen[0])

    def new(self):
        if not self.may_discard():
            return
        self.draft_id = None
        names = {v["name"] for v in self.library.patterns.values()}
        index = 1
        while f"图案{index}" in names:
            index += 1
        self.pattern = Pattern()
        self.saved_rows, self.saved_name = self.pattern.rows, f"图案{index}"
        self.name.set(self.saved_name)
        self.templates.selection_remove(*self.templates.selection())
        self.history.clear()
        self.draw()

    def persist(self, candidate):
        try:
            self.storage_dir.mkdir(parents=True, exist_ok=True)
            candidate.save(self.path)
        except (OSError, ValueError, TypeError) as error:
            self.notice.set(f"图案库未保存：{error}")
            return False
        self.library = candidate
        return True

    def save_pattern(self):
        candidate = PatternLibrary.from_document(self.library.document())
        try:
            key = candidate.put(self.name.get(), self.pattern, self.draft_id)
        except ValueError as error:
            self.notice.set(str(error))
            return False
        if not self.persist(candidate):
            return False
        self.draft_id = key
        self.saved_rows, self.saved_name = self.pattern.rows, candidate.patterns[key]["name"]
        self.name.set(self.saved_name)
        self.refresh_lists()
        self.notice.set(f"已保存图案“{self.saved_name}”及当前切换列表；未改变板端输出")
        return True

    def delete_pattern(self):
        key = self.draft_id
        if key not in self.library.patterns:
            return
        if not messagebox.askyesno("删除图案", f"删除“{self.library.patterns[key]['name']}”及其播放项？", parent=self.frame):
            return
        candidate = PatternLibrary.from_document(self.library.document())
        candidate.delete(key)
        if self.persist(candidate):
            self.saved_rows, self.saved_name = self.pattern.rows, self.name.get().strip()
            self.draft_id = None
            self.refresh_lists()
            if self.library.patterns:
                self._activate(next(iter(self.library.patterns)))
            else:
                self.new()

    def edit(self, pattern, remember=True):
        if pattern.rows == self.pattern.rows:
            return
        if remember:
            self.history.append(self.pattern.rows)
            self.history = self.history[-100:]
        self.pattern = pattern
        self.draw()

    def undo(self):
        if self.history:
            self.pattern = Pattern(self.history.pop())
            self.draw()

    def set_line(self, axis, value):
        try:
            index = int(self.row.get() if axis == "row" else self.column.get())
            self.edit(self.pattern.line(axis, index, value))
        except ValueError as error:
            self.notice.set(str(error))

    def paint_start(self, event):
        self.drag_cells = set()
        self.paint_drag(event)

    def paint_drag(self, event):
        x, y = self.canvas.canvasx(event.x), self.canvas.canvasy(event.y)
        cell = self.topology.hit_cell(x, y)
        if cell:
            if self.drag_cells is None or cell in self.drag_cells:
                return
            if not self.drag_cells:
                self.history.append(self.pattern.rows)
                self.history = self.history[-100:]
            self.drag_cells.add(cell)
            row, column = cell
            self.row.set(str(row))
            self.column.set(str(column))
            value = 1 - int(self.pattern.rows[row - 1][column - 1]) if self.brush.get() == "toggle" else int(self.brush.get())
            self.edit(self.pattern.cell(row, column, value), remember=False)
        elif self.drag_cells == set():
            x0, y0, pitch, gap = self.topology.grid_geometry
            if x0 <= x < x0 + 20 * pitch and y0 - 20 <= y < y0:
                self.column.set(str(int((x - x0) // pitch) + 1))
            elif x0 - 30 <= x < x0:
                dy = y - y0
                if 10 * pitch <= dy < 10 * pitch + gap:
                    return
                if dy >= 10 * pitch + gap:
                    dy -= gap
                if 0 <= dy < 20 * pitch:
                    self.row.set(str(int(dy // pitch) + 1))
            self.draw()

    def draw(self):
        if not self.alive:
            return
        try:
            row, column = int(self.row.get()), int(self.column.get())
            focus = (row, column) if 1 <= row <= 20 and 1 <= column <= 20 else None
        except ValueError:
            focus = None
        self.topology.draw(preview=self.pattern.rows, focus=focus)
        self.update_summary()

    def read_board(self):
        if not self.app.connected or not self.app.latest:
            self.notice.set("请先连接板卡读取最新命令镜像")
            return
        try:
            self.edit(from_image(bytes.fromhex(self.app.latest["image"]), self.mapping.model))
            self.notice.set("已读取板端命令镜像到编辑区；不是实际电压回读，请命名并保存")
        except ValueError as error:
            self.notice.set(str(error))

    def selected_step(self):
        selection = self.steps.selection()
        return int(selection[0]) if selection else None

    def refresh_lists(self, select_step=None):
        self.templates.delete(*self.templates.get_children())
        for key, p in self.library.patterns.items():
            self.templates.insert("", "end", iid=key, values=(p["name"], Pattern(p["rows"]).count()))
        if self.draft_id in self.library.patterns:
            self.templates.selection_set(self.draft_id)
        self.steps.delete(*self.steps.get_children())
        for index, step in enumerate(self.library.playlist):
            self.steps.insert("", "end", iid=str(index), values=(index + 1, self.library.patterns[step["pattern"]]["name"], step["dwell_ms"]))
        if select_step is not None and 0 <= select_step < len(self.library.playlist):
            self.steps.selection_set(str(select_step))
        self.update_state()

    def add_step(self):
        if self.dirty() or self.draft_id is None:
            if not self.save_pattern():
                return
        try:
            candidate = PatternLibrary.from_document(self.library.document())
            candidate.add_step(self.draft_id, dwell_ms(int(self.duration.get())))
        except ValueError as error:
            self.notice.set(str(error))
            return
        if self.persist(candidate):
            self.refresh_lists(len(candidate.playlist) - 1)
            self.notice.set("已加入切换列表，可在“切换列表”页调整顺序、时长和播放方式")

    def select_step(self, _event=None):
        index = self.selected_step()
        if index is not None and index < len(self.library.playlist):
            self.duration.set(str(self.library.playlist[index]["dwell_ms"]))
        self.app.refresh_pending()

    def preview_step(self):
        index = self.selected_step()
        if index is not None and self.may_discard():
            self._activate(self.library.playlist[index]["pattern"])

    def move_step(self, delta):
        index = self.selected_step()
        if index is None or not 0 <= index + delta < len(self.library.playlist):
            return
        candidate = PatternLibrary.from_document(self.library.document())
        candidate.playlist[index], candidate.playlist[index + delta] = candidate.playlist[index + delta], candidate.playlist[index]
        if self.persist(candidate):
            self.refresh_lists(index + delta)

    def remove_step(self):
        index = self.selected_step()
        if index is not None:
            candidate = PatternLibrary.from_document(self.library.document())
            candidate.playlist.pop(index)
            if self.persist(candidate):
                self.refresh_lists(min(index, len(candidate.playlist) - 1))

    def set_duration(self, all_steps=False):
        try:
            duration = dwell_ms(int(self.duration.get()))
        except ValueError as error:
            self.notice.set(str(error))
            return
        index = self.selected_step()
        candidate = PatternLibrary.from_document(self.library.document())
        for i, step in enumerate(candidate.playlist):
            if all_steps or i == index:
                step["dwell_ms"] = duration
        if self.persist(candidate):
            self.refresh_lists(index)

    def set_mode(self, _event=None):
        candidate = PatternLibrary.from_document(self.library.document())
        candidate.mode = next(k for k, v in MODES.items() if v == self.mode.get())
        if not self.persist(candidate):
            self.mode.set(MODES[self.library.mode])
        self.app.refresh_pending()

    def _send_play_frame(self, command, callback):
        return self.app.send_play_frame(command, callback, self.player)

    def _player_event(self, event, index, text):
        if event == "stopped":
            self.play_status.set(text)
            self.app.playback_plan = None
        else:
            self.play_status.set(f"第{index + 1}/{len(self.player.steps)}项 · {text} · {'等待确认' if event == 'sending' else '已确认 / 保持中'}")
        self.update_state()
        self.app.refresh_status()

    def start(self):
        self.output_action = "playlist"
        self.notice.set("已选择列表播放；通过右上角总按钮应用当前列表、时长和模式。")
        self.app.refresh_pending()

    def stage_stop(self):
        self.output_action = "stop"
        self.notice.set("已选择停止 / 保持；当前播放继续，点击右上角总按钮后停止。")
        self.app.refresh_pending()

    def prepare_action(self):
        if self.output_action == "stop":
            return OutputAction("command", "STOP", "停止图案切换 / 保持当前输出")
        if self.output_action == "playlist":
            if not self.library.playlist:
                raise ValueError("请先向切换列表添加图案。")
            snapshot = []
            frames = {}
            for step in self.library.playlist:
                key = step["pattern"]
                item = self.library.patterns[key]
                if key not in frames:
                    frames[key] = compile_frame(Pattern(item["rows"]), self.mapping.model)
                snapshot.append(PlaybackStep(item["name"], frames[key], dwell_ms(step["dwell_ms"])))
            return OutputAction("playlist", PlaylistPlan(tuple(snapshot), self.library.mode),
                                f"{MODES[self.library.mode]} · {len(snapshot)} 个播放项")
        if self.output_action == "step":
            index = self.selected_step()
            if index is None:
                raise ValueError("请先选择一个播放项。")
            item = self.library.patterns[self.library.playlist[index]["pattern"]]
            pattern, name = Pattern(item["rows"]), item["name"]
        elif self.output_action == "custom":
            pattern, name = self.output_pattern
        else:
            pattern, name = self.pattern, self.name.get()
        image = compile_frame(pattern, self.mapping.model)
        def completed(reply, error):
            confirmed = not error and reply and reply["ok"] and not reply["errors"] and reply["oe"] and not reply["blink_ms"] and not active_frequency(reply) and reply["image"].upper() == image.hex().upper()
            self.notice.set(f"已确认“{name}”，保持静态图案" if confirmed else f"“{name}”下发未确认，请检查连接和板端状态")
        return OutputAction("command", "FRAME " + image.hex().upper(), f"图案“{name}” · {pattern.count()}/400 路高", completed)

    def preview_action(self):
        """Cheap draft summary: do not compile a 1024-item list on each redraw."""
        if self.output_action == "stop":
            return OutputAction("command", "STOP", "停止图案切换 / 保持当前输出")
        if self.mapping_error:
            raise ValueError(self.mapping_error)
        if self.output_action == "playlist":
            if not self.library.playlist:
                raise ValueError("请先向切换列表添加图案。")
            return OutputAction("playlist", None, f"{MODES[self.library.mode]} · {len(self.library.playlist)} 个播放项")
        if self.output_action == "step":
            index = self.selected_step()
            if index is None:
                raise ValueError("请先选择一个播放项。")
            item = self.library.patterns[self.library.playlist[index]["pattern"]]
            pattern, name = Pattern(item["rows"]), item["name"]
        elif self.output_action == "custom":
            pattern, name = self.output_pattern
        else:
            pattern, name = self.pattern, self.name.get()
        return OutputAction("command", None, f"图案“{name}” · {pattern.count()}/400 路高")

    def begin_playback(self, plan):
        self.player.start([{"name": step.name, "image": step.image, "dwell_ms": step.dwell_ms} for step in plan.steps], plan.mode)

    def stop(self, reason="已停止，保持最后已下发图案"):
        self.player.stop(reason)

    def apply_pattern(self, pattern, name):
        self.output_action = "custom"
        self.output_pattern = (Pattern(pattern.rows), name)
        self.notice.set(f"已选择图案“{name}”；点击右上角总按钮应用。")
        self.app.refresh_pending()

    def apply_draft(self):
        self.output_action = "draft"
        self.notice.set("已选择编辑图案；继续编辑后，经总按钮应用最新图案。")
        self.app.refresh_pending()

    def apply_step(self):
        index = self.selected_step()
        if index is not None:
            self.output_action = "step"
            self.notice.set("已选择当前播放项；经右上角总按钮应用。")
            self.app.refresh_pending()

    def manual_step(self, direction):
        count = len(self.library.playlist)
        if not count:
            return
        index = self.selected_step()
        index = (index + direction) % count if index is not None else (0 if direction > 0 else count - 1)
        self.steps.selection_set(str(index))
        self.apply_step()

    def import_library(self):
        if not self.may_discard():
            return
        picked = filedialog.askopenfilename(parent=self.frame, initialdir=self.storage_dir,
                                            filetypes=[("RIS图案库", "*.json")])
        if not picked:
            return
        self.load_library(picked)

    def load_library(self, path):
        try:
            candidate = PatternLibrary.load(path)
            if self.path.exists():
                backup = self.storage_dir / "backups"
                backup.mkdir(parents=True, exist_ok=True)
                shutil.copy2(self.path, backup / f"library_{datetime.now().strftime('%Y%m%d_%H%M%S_%f')}.json")
        except (OSError, ValueError, TypeError) as error:
            self.notice.set(f"图案库未导入，当前内容保留：{error}")
            return False
        if not self.persist(candidate):
            return False
        self.draft_id = None
        self.refresh_lists()
        if self.library.patterns:
            self._activate(next(iter(self.library.patterns)))
        else:
            self.pattern = Pattern()
            self.saved_rows, self.saved_name = self.pattern.rows, "新图案"
            self.name.set(self.saved_name)
            self.draw()
        self.mode.set(MODES[self.library.mode])
        self.notice.set("图案库及播放方式已导入；当前输出保持，新配置经总按钮应用")
        return True

    def export_library(self):
        if self.dirty() and not self.save_pattern():
            return
        picked = filedialog.asksaveasfilename(parent=self.frame, initialdir=self.storage_dir,
                                             initialfile="ris_patterns.json", defaultextension=".json",
                                             filetypes=[("RIS图案库", "*.json")])
        if picked:
            try:
                self.library.save(picked)
                self.notice.set(f"已导出图案库：{picked}")
            except (OSError, ValueError) as error:
                self.notice.set(f"导出失败：{error}")

    def update_state(self):
        if not self.alive:
            return
        document = self.mapping.model.document()
        if document != self.mapping_document:
            self.mapping_document = document
            try:
                compile_frame(Pattern(), self.mapping.model)
                self.mapping_error = ""
            except ValueError as error:
                self.mapping_error = str(error)
        available = not self.mapping_error
        for control in self.edit_controls:
            control.configure(state="normal")
        self.mode_box.configure(state="readonly")
        for button in (self.apply_button, self.step_button, self.previous_button, self.next_button):
            button.configure(state="normal" if available else "disabled")
        self.start_button.configure(state="normal" if available and self.library.playlist else "disabled")
        self.stop_button.configure(state="normal")
        self.draw()

    def shutdown(self):
        self.player.stop(notify=False)
        self.alive = False
