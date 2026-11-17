"""File selection and preview; loading/editing never sends output commands."""
from pathlib import Path
from decimal import Decimal
import tkinter as tk
from tkinter import ttk, filedialog

from ris_mt import DEFAULT_MT_DIRECTORY, MAX_ROWS, compile_mt, load_mt, validate_preamble
from ris_mt_preview import MTPreview


class MTControls:
    def __init__(self, app, parent):
        self.app = app
        self.rows = None
        self.path = None
        self._plan_key = self._plan = None
        self.loop = tk.BooleanVar(value=True)
        self.preamble_enabled = tk.BooleanVar(value=False)
        self.preamble_rows = ()
        self.preamble_path = None
        self.preamble_text = tk.StringVar(value="未加载前导码；格式(M,T);，最多10行，M+T不大于100%。")
        self.file_text = tk.StringVar(value="默认方波：M=50%，T=0%；可加载 MATLAB 导出的 MT 文本表")
        self.mode = tk.StringVar(value="uniform")
        row = ttk.Frame(parent)
        row.pack(fill="x", pady=(5, 0))
        ttk.Label(row, text="单元控制：").pack(side="left")
        ttk.Radiobutton(row, text="400 路统一", variable=self.mode, value="uniform").pack(side="left")
        ttk.Radiobutton(row, text="400 路独立（后续支持）", variable=self.mode,
                        value="independent", state="disabled").pack(side="left", padx=8)
        self.load_button = ttk.Button(row, text="加载 MT 时域表", command=self.choose)
        self.load_button.pack(side="left", padx=6)
        ttk.Button(row, text="预览", command=self.preview).pack(side="left", padx=4)
        ttk.Button(row, text="恢复默认方波", command=self.clear).pack(side="left", padx=4)
        self.cancel_button = ttk.Button(row, text="选择取消上传", command=app.stage_mt_stop, state="disabled")
        self.cancel_button.pack(side="left", padx=4)
        playback = ttk.Frame(parent)
        playback.pack(fill="x", pady=(5, 0))
        ttk.Label(playback, text="MT 播放：").pack(side="left")
        self.once_button = ttk.Button(playback, text="选择 MT 播放一次", command=lambda: self.start(False))
        self.once_button.pack(side="left", padx=4)
        self.loop_button = ttk.Button(playback, text="选择 MT 循环播放", command=lambda: self.start(True))
        self.loop_button.pack(side="left", padx=4)
        self.stop_button = ttk.Button(playback, text="选择停止 / 保持", command=app.stage_mt_stop)
        self.stop_button.pack(side="left", padx=4)
        ttk.Label(playback, text="选择后，经右上角总按钮应用。").pack(side="left", padx=8)
        ttk.Label(parent, textvariable=self.file_text, wraplength=1060).pack(anchor="w", pady=(3, 0))
        prefix = ttk.LabelFrame(parent, text="前导码MT表", padding=10)
        prefix.pack(fill="x", pady=(12, 0))
        buttons = ttk.Frame(prefix)
        buttons.pack(fill="x")
        self.preamble_checkbox = ttk.Checkbutton(buttons, text="启用前导码", variable=self.preamble_enabled)
        self.preamble_checkbox.pack(side="left")
        self.preamble_load_button = ttk.Button(buttons, text="加载前导码MT表", command=self.choose_preamble)
        self.preamble_load_button.pack(side="left", padx=12)
        ttk.Label(prefix, textvariable=self.preamble_text, wraplength=1020).pack(anchor="w", pady=(6, 0))
        ttk.Label(prefix, text="每行一个PWM周期，与正式MT内容共用频率和周期边界；每次循环先发前导码，再发正式内容。\n"
                  "未加载正式MT表时，正式内容为一个默认50%方波周期；前导码与正式表合计最多512行。",
                  wraplength=1020, style="Muted.TLabel").pack(anchor="w", pady=(5, 0))
        self.loop.trace_add("write", lambda *_: app.refresh_pending())
        self.preamble_enabled.trace_add("write", self._preamble_changed)

    @property
    def has_table(self):
        return bool(self.rows) or self.preamble_enabled.get()

    @staticmethod
    def _validate_preamble(rows):
        validate_preamble(rows)

    def _preamble_changed(self, *_):
        if self.preamble_rows:
            self.preamble_text.set(f"{self.preamble_path.name} · {len(self.preamble_rows)}个周期 · "
                                   f"{'已启用' if self.preamble_enabled.get() else '未启用'} · 经总下发按钮应用")
        self.update_state()
        self.app.refresh_pending()

    def choose_preamble(self):
        path = filedialog.askopenfilename(parent=self.app.root, title="加载前导码MT表",
                                         initialdir=str(DEFAULT_MT_DIRECTORY),
                                         filetypes=[("MT 文本表", "*.txt *.mt *.csv"), ("所有文件", "*")])
        if path:
            self.load_preamble(path)

    def load_preamble(self, path):
        try:
            rows = load_mt(path)
            self._validate_preamble(rows)
        except (OSError, UnicodeError, ValueError) as error:
            self.app.notice.set(f"前导码未载入，保留原配置：{error}")
            return False
        self.preamble_rows, self.preamble_path = rows, Path(path)
        self.preamble_enabled.set(True)
        self.app.notice.set("前导码已载入配置快照；点击右上角总下发按钮后应用。")
        return True

    def update_state(self):
        enabled = self.has_table
        for button in (self.once_button, self.loop_button):
            button.configure(state="normal" if enabled else "disabled")
        self.stop_button.configure(state="normal")
        self.cancel_button.configure(state="normal" if self.app.mt_uploading else "disabled")

    def start(self, loop):
        if not self.has_table:
            self.app.notice.set("请先加载 MT 时域表")
            return False
        self.app.stage_mt(loop)
        return True

    def choose(self):
        path = filedialog.askopenfilename(parent=self.app.root, title="加载 MT 时域表",
                                         initialdir=str(DEFAULT_MT_DIRECTORY),
                                         filetypes=[("MT 文本表", "*.txt *.mt *.csv"), ("所有文件", "*")])
        if path:
            self.load(path)

    def load(self, path):
        try:
            rows = load_mt(path)
        except (OSError, UnicodeError, ValueError) as error:
            self.app.notice.set(f"加载失败，保留原表：{error}")
            return False
        self.rows, self.path = rows, Path(path)
        self.file_text.set(f"{self.path.name} · {len(rows)} 个周期 · M=占空比%，T=延时% · 超出周期末尾的高电平回绕到本周期开头")
        self.app.stage_mt()
        self.update_state()
        return True

    def clear(self):
        self.rows, self.path = None, None
        self.file_text.set("默认方波：M=50%，T=0%；点击右上角总按钮后生效")
        self.app.stage_mt()
        self.update_state()

    def plan(self):
        prefix = ()
        if self.preamble_enabled.get():
            if not self.preamble_rows:
                raise ValueError("已启用前导码，请先加载前导码MT表")
            self._validate_preamble(self.preamble_rows)
            prefix = self.preamble_rows
        rows = prefix + (self.rows or ((Decimal(50), Decimal(0)),))
        if len(rows) > MAX_ROWS:
            raise ValueError(f"前导码与正式MT表合计最多{MAX_ROWS}行，请缩短MT表")
        key = (rows, self.app.fast_value.get(), self.app.fast_unit.get(), self.loop.get())
        if key != self._plan_key:
            plan = compile_mt(*key)
            self._plan_key, self._plan = key, plan
        return self._plan

    def preview(self):
        if not self.has_table:
            self.app.notice.set("请先加载 MT 时域表；默认方波为 50% 占空比、0% 延时")
            return
        try:
            plan = self.plan()
        except ValueError as error:
            self.app.notice.set(str(error))
            return
        return MTPreview(self.app.root, plan)
