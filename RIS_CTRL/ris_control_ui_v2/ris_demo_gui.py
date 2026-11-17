"""Ten offline preset slots; selecting a row never applies an output."""
from dataclasses import dataclass, replace
from pathlib import Path
import tkinter as tk
from tkinter import ttk, filedialog

from ris_actions import OutputAction
from ris_mt import DEFAULT_CONFIG_DIRECTORY
from ris_presets import MAX_FILE_BYTES, MAX_SLOTS, action_from_document, load_preset, read_json, write_json


@dataclass(frozen=True)
class PresetEntry:
    path: str
    filename: str
    document: dict
    action: OutputAction


class DemoPage:
    def __init__(self, app, parent, storage):
        self.app = app
        self.storage = Path(storage) / "demo_slots.json"
        self.entries = [None] * MAX_SLOTS
        self.selected = None
        self.stop_selected = False
        self.select_buttons, self.load_buttons = [], []
        self.selection_text = tk.StringVar(value="尚未选择预设；请先加载文件，再点击对应行的“选择该模式”。")
        self.notice = tk.StringVar(value="加载和选择均不改变当前输出；点击右上角“下发指令”后才应用。")
        style = ttk.Style(parent)
        style.configure("Preset.TButton", padding=(10, 2))
        style.configure("SelectedPreset.TButton", padding=(10, 2), background="#2563eb", foreground="white")
        style.map("SelectedPreset.TButton", background=[("active", "#1d4ed8")])
        scroll = ttk.Frame(parent)
        scroll.pack(fill="both", expand=True)
        self.canvas = tk.Canvas(scroll, background="#f4f6f9", highlightthickness=0)
        scrollbar = ttk.Scrollbar(scroll, orient="vertical", command=self.canvas.yview)
        scrollbar.pack(side="right", fill="y")
        self.canvas.configure(yscrollcommand=scrollbar.set)
        self.canvas.pack(side="left", fill="both", expand=True)
        body = ttk.Frame(self.canvas)
        window = self.canvas.create_window(0, 0, anchor="nw", window=body)
        body.bind("<Configure>", lambda _: self.canvas.configure(scrollregion=self.canvas.bbox("all")))
        self.canvas.bind("<Configure>", lambda event: self.canvas.itemconfigure(window, width=event.width))
        self.canvas.bind("<MouseWheel>", lambda event: self.canvas.yview_scroll(-int(event.delta/120), "units"))
        self.canvas.bind("<Button-4>", lambda _: self.canvas.yview_scroll(-1, "units"))
        self.canvas.bind("<Button-5>", lambda _: self.canvas.yview_scroll(1, "units"))
        title = ttk.Frame(body)
        title.pack(fill="x", pady=(0, 6))
        ttk.Label(title, text="演示模式", font=("sans", 16, "bold")).pack(side="left")
        ttk.Button(title, text="选择停止 / 保持", command=self.stage_stop).pack(side="right")
        self.selection_label = ttk.Label(body, textvariable=self.selection_text, foreground="#1e5c9c", wraplength=1050)
        self.selection_label.pack(fill="x", pady=(0, 8))
        self.table = ttk.Frame(body)
        self.table.pack(fill="x")
        self.table.columnconfigure(2, weight=1)
        for index in range(MAX_SLOTS):
            ttk.Label(self.table, text=f"{index+1:02d}", width=3, anchor="center").grid(row=index, column=0, padx=(0, 8), pady=2)
            select = ttk.Button(self.table, text="选择该模式", style="Preset.TButton", width=16,
                                command=lambda i=index: self.select(i), state="disabled")
            select.grid(row=index, column=1, sticky="ew", padx=(0, 12), pady=2)
            load = ttk.Button(self.table, text="请加载预设", style="Preset.TButton", width=1,
                              command=lambda i=index: self.choose(i))
            load.grid(row=index, column=2, sticky="ew", pady=2)
            self.select_buttons.append(select)
            self.load_buttons.append(load)
        self.note_label = ttk.Label(body, textvariable=self.notice, style="Muted.TLabel", wraplength=1050)
        self.note_label.pack(fill="x", pady=(10, 0))
        ttk.Label(body, text="在其他功能页配置好内容后，点击上方“导出当前配置”，即可生成这里使用的JSON预设。",
                  style="Muted.TLabel", wraplength=1050).pack(anchor="w", pady=(5, 0))
        parent.bind("<Configure>", self._wrap)
        self.restore()

    def _wrap(self, event):
        for label in (self.selection_label, self.note_label):
            label.configure(wraplength=max(1, event.width-28))

    def choose(self, index):
        path = filedialog.askopenfilename(parent=self.app.root, title=f"加载第{index+1}行预设",
                                         initialdir=str(DEFAULT_CONFIG_DIRECTORY),
                                         filetypes=[("RIS预设JSON", "*.json")])
        if path:
            return self.load(index, path)
        return False

    def _cache_document(self, entries):
        return {"format": "ris-demo-slots", "version": 1,
                "slots": [({"path": entry.path, "filename": entry.filename, "preset": entry.document}
                           if entry else None) for entry in entries]}

    def load(self, index, path):
        if type(index) is not int or not 0 <= index < MAX_SLOTS:
            raise ValueError("演示预设行号超出范围")
        try:
            path = Path(path).resolve()
            document, action = load_preset(path)
            entries = list(self.entries)
            entries[index] = PresetEntry(str(path), path.name, document, action)
            # Persist the validated snapshot, not a dependency on a mutable file.
            write_json(self.storage, self._cache_document(entries))
        except (OSError, ValueError) as error:
            self.notice.set(f"第{index+1}行未载入，保留原预设：{error}")
            return False
        self.entries = entries
        self.load_buttons[index].configure(text=path.name)
        self.select_buttons[index].configure(state="normal")
        if self.selected == index:
            self.selected = None
            self.select_buttons[index].configure(style="Preset.TButton")
            self.selection_text.set("该行已加载新预设，请重新点击“选择该模式”。当前输出保持。")
        self.notice.set(f"已加载第{index+1}行：{path.name}。预设已保存在本控制台，重新启动后仍可选择。")
        self.app.refresh_pending()
        return True

    def select(self, index):
        if type(index) is not int or not 0 <= index < MAX_SLOTS or self.entries[index] is None:
            self.notice.set("请先加载这一行的预设。")
            return False
        self.selected, self.stop_selected = index, False
        entry = self.entries[index]
        for i, button in enumerate(self.select_buttons):
            button.configure(style="SelectedPreset.TButton" if i == index else "Preset.TButton")
        self.selection_text.set(f"已选择第{index+1:02d}行 · {entry.filename}\n{entry.action.summary}")
        self.notice.set("已更新待下发预设；当前输出保持，点击右上角总按钮应用。")
        self.app.refresh_pending()
        return True

    def stage_stop(self):
        self.selected, self.stop_selected = None, True
        for button in self.select_buttons:
            button.configure(style="Preset.TButton")
        self.selection_text.set("已选择停止 / 保持；点击右上角总按钮后应用。")
        self.app.refresh_pending()

    def prepare_action(self):
        if self.stop_selected:
            return OutputAction("command", "STOP", "停止演示 / 保持当前输出")
        if self.selected is None:
            raise ValueError("请先加载预设，并点击对应行的“选择该模式”。")
        entry = self.entries[self.selected]
        return replace(entry.action, summary=f"演示{self.selected+1:02d} · {entry.filename} · {entry.action.summary}")

    def restore(self):
        if not self.storage.exists():
            return
        try:
            cache = read_json(self.storage, MAX_SLOTS*MAX_FILE_BYTES + 65536)
            if (cache.get("format") != "ris-demo-slots" or type(cache.get("version")) is not int or
                    cache["version"] != 1 or not isinstance(cache.get("slots"), list) or len(cache["slots"]) != MAX_SLOTS):
                raise ValueError("演示模式保存格式有误")
            failures = []
            for i, item in enumerate(cache["slots"]):
                if item is None:
                    continue
                try:
                    action = action_from_document(item["preset"])
                    if not isinstance(item["filename"], str) or not 1 <= len(item["filename"]) <= 255 or not isinstance(item["path"], str):
                        raise ValueError("文件名有误")
                    self.entries[i] = PresetEntry(item["path"], item["filename"], item["preset"], action)
                    self.load_buttons[i].configure(text=item["filename"])
                    self.select_buttons[i].configure(state="normal")
                except (ValueError, KeyError, TypeError):
                    failures.append(str(i+1))
            count = sum(entry is not None for entry in self.entries)
            self.notice.set(f"已恢复{count}条预设，尚未选择或下发。" + (f" 第{'、'.join(failures)}行无法恢复，请重新加载。" if failures else ""))
        except (OSError, ValueError, AttributeError) as error:
            self.notice.set(f"演示预设未恢复，请重新加载：{error}")
