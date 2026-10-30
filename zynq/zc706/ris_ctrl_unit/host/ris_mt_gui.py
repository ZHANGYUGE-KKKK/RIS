"""File selection and preview; loading/editing never sends output commands."""
from pathlib import Path
import tkinter as tk
from tkinter import ttk, filedialog

from ris_frequency import frequency_text
from ris_mt import compile_mt, load_mt, rounded


class MTControls:
    def __init__(self, app, parent):
        self.app = app
        self.rows = None
        self.path = None
        self.loop = tk.BooleanVar(value=True)
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
        self.cancel_button = ttk.Button(row, text="取消上传", command=app.mt_cancel.set, state="disabled")
        self.cancel_button.pack(side="left", padx=4)
        playback = ttk.Frame(parent)
        playback.pack(fill="x", pady=(5, 0))
        ttk.Label(playback, text="MT 播放：").pack(side="left")
        self.once_button = ttk.Button(playback, text="MT 播放一次", command=lambda: self.start(False))
        self.once_button.pack(side="left", padx=4)
        self.loop_button = ttk.Button(playback, text="MT 循环播放", command=lambda: self.start(True))
        self.loop_button.pack(side="left", padx=4)
        self.stop_button = ttk.Button(playback, text="停止 MT / 保持", command=lambda: app.command("STOP"))
        self.stop_button.pack(side="left", padx=4)
        ttk.Label(playback, text="按表中顺序播放；循环整表直到点击停止。").pack(side="left", padx=8)
        ttk.Label(parent, textvariable=self.file_text, wraplength=1060).pack(anchor="w", pady=(3, 0))

    def update_state(self):
        enabled = (self.rows and self.app.connected and not self.app.busy and
                   self.app.latest and self.app.latest.get("mt_supported"))
        for button in (self.once_button, self.loop_button):
            button.configure(state="normal" if enabled else "disabled")
        self.stop_button.configure(state="normal" if self.app.connected and not self.app.busy else "disabled")
        self.cancel_button.configure(state="normal" if self.app.mt_uploading else "disabled")

    def start(self, loop):
        if self.app.busy:
            return False
        if not self.rows:
            self.app.notice.set("请先加载 MT 时域表")
            return False
        self.loop.set(bool(loop))
        self.app.preview_frequency()
        return self.app.start_fast()

    def choose(self):
        path = filedialog.askopenfilename(parent=self.app.root, title="加载 MT 时域表",
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
        self.app.preview_frequency()
        self.update_state()
        return True

    def clear(self):
        self.rows, self.path = None, None
        self.file_text.set("默认方波：M=50%，T=0%；恢复或加载文件只编辑，下次点击启动时生效")
        self.app.preview_frequency()
        self.update_state()

    def plan(self):
        return compile_mt(self.rows, self.app.fast_value.get(), self.app.fast_unit.get(), self.loop.get())

    def preview(self):
        if not self.rows:
            self.app.notice.set("请先加载 MT 时域表；默认方波为 50% 占空比、0% 延时")
            return
        try:
            plan = self.plan()
        except ValueError as error:
            self.app.notice.set(str(error))
            return
        window = tk.Toplevel(self.app.root)
        preview_count = min(10, len(plan.rows))
        window.title(f"MT 表与实际输出预览 · 前 {preview_count} 个周期")
        ttk.Label(window, text=f"400 路统一 · {frequency_text(plan.actual)} · "
                  f"{'循环' if plan.loop else '一次，整表结束后置低'} · "
                  f"预览 {preview_count} / {len(plan.rows)} 个周期 · 100 ns 最小边沿间隔").pack(padx=12, pady=8)
        canvas = tk.Canvas(window, width=880, height=150, background="white")
        canvas.pack(fill="x", padx=12)
        span = preview_count * plan.period
        xscale = 800 / span
        for cycle in range(preview_count + 1):
            x = 40 + cycle * plan.period * xscale
            canvas.create_line(x, 20, x, 120, fill="#ccd4df", dash=(3, 3))
            canvas.create_text(x, 135, text=f"{cycle}P")
        time, level = 0, 0
        sequence = [(0, plan.initial_delay)] + list(plan.segments)
        for value, ticks in sequence:
            if time >= span:
                break
            x1, x2 = 40 + time * xscale, 40 + min(span, time + ticks) * xscale
            y1, y2 = 110 - level * 75, 110 - value * 75
            canvas.create_line(x1, y1, x1, y2, x2, y2, fill="#176796", width=2)
            time += ticks
            level = value
        tree = ttk.Treeview(window, columns=("n", "m", "t", "qm", "qt"), show="headings", height=preview_count)
        for name, label in zip(tree['columns'], ("周期", "M (%)", "T (%)", "量化 M (%)", "量化 T (%)")):
            tree.heading(name, text=label)
            tree.column(name, width=160, anchor="center")
        for index, (m, t) in enumerate(plan.rows[:preview_count], 1):
            tree.insert('', 'end', values=(index, str(m), str(t),
                        f"{rounded(m * plan.period / 100) / plan.period * 100:.6g}",
                        f"{rounded(t * plan.period / 100) / plan.period * 100:.6g}"))
        tree.pack(fill="both", expand=True, padx=12, pady=8)
        ttk.Label(window, text="曲线和表格显示 MT 表前 10 个周期，不足 10 个时显示全部；实际播放仍使用完整表。\n"
                  "M+T>100% 时高电平回绕到本周期开头，每个周期独立。预览不会改变板卡输出。",
                  wraplength=860).pack(padx=12, pady=8)
