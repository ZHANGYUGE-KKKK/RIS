"""Scrollable, offline view of one complete compiled MT frame."""
import math
import tkinter as tk
from tkinter import ttk

from ris_frequency import frequency_text
from ris_mt import pulse_ticks


class MTPreview(tk.Toplevel):
    MARGIN = 40

    def __init__(self, parent, plan):
        super().__init__(parent)
        self.plan = plan
        count = len(plan.rows)
        self.period_width = 800 / min(10, count)
        self.content_width = 2 * self.MARGIN + count * self.period_width
        self.visible_text = tk.StringVar(master=self)
        self.title(f"MT 表与实际输出预览 · 共 {count} 个周期")
        self.transient(parent)
        self.geometry(f"{min(960, self.winfo_screenwidth()-80)}x{min(600, self.winfo_screenheight()-100)}")
        self.minsize(640, 420)
        ttk.Label(self, text=f"400 路统一 · {frequency_text(plan.actual)} · "
                  f"{'循环' if plan.loop else '一次，整表结束后置低'} · "
                  f"完整序列 {count} 个周期 · 100 ns 最小边沿间隔").pack(anchor="w", padx=12, pady=8)
        plot = ttk.Frame(self)
        plot.pack(fill="x", padx=12)
        self.waveform = tk.Canvas(plot, width=880, height=150, background="white", highlightthickness=0,
                                  scrollregion=(0, 0, self.content_width, 150))
        self.waveform.pack(fill="x")
        self.wave_scroll = ttk.Scrollbar(plot, orient="horizontal", command=self.waveform.xview)
        self.wave_scroll.pack(fill="x")
        self.waveform.configure(xscrollcommand=self._wave_view_changed)
        ttk.Label(self, textvariable=self.visible_text, foreground="#315b80").pack(anchor="w", padx=12, pady=(5, 0))
        self._draw_waveform()
        self.help_label = ttk.Label(self, text="波形可拖动下方滚动条或用鼠标滚轮向后查看；表格可上下滚动，点击行定位对应波形。\n"
                                    "M+T>100% 时高电平回绕到本周期开头，每个周期独立。预览不会改变板卡输出。",
                                    wraplength=610)
        self.help_label.pack(side="bottom", anchor="w", padx=12, pady=(0, 10))

        table_frame = ttk.Frame(self)
        table_frame.pack(fill="both", expand=True, padx=12, pady=8)
        self.table = ttk.Treeview(table_frame, columns=("n", "m", "t", "qm", "qt"),
                                  show="headings", height=min(10, count), selectmode="browse")
        for name, label, width in zip(self.table['columns'],
                                     ("周期", "M (%)", "T (%)", "量化 M (%)", "量化 T (%)"),
                                     (100, 140, 140, 180, 180)):
            self.table.heading(name, text=label)
            self.table.column(name, width=width, minwidth=50, anchor="center")
        self.table_scroll = ttk.Scrollbar(table_frame, orient="vertical", command=self.table.yview)
        self.table_scroll.pack(side="right", fill="y")
        self.table.configure(yscrollcommand=self.table_scroll.set)
        self.table.pack(side="left", fill="both", expand=True)
        for index, (m, t) in enumerate(plan.rows, 1):
            delay, width = pulse_ticks(m, t, plan.period)
            self.table.insert('', 'end', iid=str(index), values=(index, str(m), str(t),
                              f"{width / plan.period * 100:.6g}",
                              f"{delay / plan.period * 100:.6g}"))
        self.table.bind("<<TreeviewSelect>>", self._select_cycle)
        self.table.bind("<Configure>", self._fit_columns)
        for event in ("<MouseWheel>", "<Shift-MouseWheel>", "<Button-4>", "<Button-5>"):
            self.waveform.bind(event, self._wheel)

    def _fit_columns(self, event):
        for name, share in zip(self.table['columns'], (0.12, 0.17, 0.17, 0.27, 0.27)):
            self.table.column(name, width=max(50, int((event.width-4) * share)))

    def _draw_waveform(self):
        canvas, plan = self.waveform, self.plan
        self.highlight = canvas.create_rectangle(0, 18, 0, 120, fill="#e7effb", outline="", state="hidden")
        for cycle in range(len(plan.rows) + 1):
            x = self.MARGIN + cycle * self.period_width
            canvas.create_line(x, 20, x, 120, fill="#ccd4df", dash=(3, 3))
            canvas.create_text(x, 135, text=f"{cycle}P", tags="cycle_label")
        span = len(plan.rows) * plan.period
        scale = self.period_width / plan.period
        time, level = 0, 0
        for value, ticks in ((0, plan.initial_delay), *plan.segments):
            if time >= span:
                break
            if not ticks:
                continue
            x1 = self.MARGIN + time * scale
            x2 = self.MARGIN + min(span, time + ticks) * scale
            y1, y2 = 110 - level * 75, 110 - value * 75
            canvas.create_line(x1, y1, x1, y2, x2, y2, fill="#176796", width=2, tags="wave")
            time += ticks
            level = value
        if not plan.loop and level:
            x = self.MARGIN + span * scale
            canvas.create_line(x, 35, x, 110, fill="#176796", width=2, tags="wave")

    def _wave_view_changed(self, first, last):
        self.wave_scroll.set(first, last)
        start = math.floor((float(first) * self.content_width - self.MARGIN) / self.period_width)
        stop = math.ceil((float(last) * self.content_width - self.MARGIN) / self.period_width)
        count = len(self.plan.rows)
        start = max(0, min(count-1, start)) + 1
        stop = max(start, min(count, stop))
        self.visible_text.set(f"当前显示第 {start}–{stop} 个周期 / 共 {count} 个周期")

    def _select_cycle(self, _event=None):
        selected = self.table.selection()
        if not selected:
            return
        index = int(selected[0]) - 1
        x = self.MARGIN + index * self.period_width
        self.waveform.coords(self.highlight, x, 18, x + self.period_width, 120)
        self.waveform.itemconfigure(self.highlight, state="normal")
        self.waveform.xview_moveto(index * self.period_width / self.content_width)

    def _wheel(self, event):
        if getattr(event, "num", None) in (4, 5):
            steps = -1 if event.num == 4 else 1
        else:
            delta = event.delta
            if not delta:
                return "break"
            steps = -int(delta / 120) if abs(delta) >= 120 else (-1 if delta > 0 else 1)
        self.waveform.xview_moveto(self.waveform.xview()[0] + steps * self.period_width / self.content_width)
        return "break"
