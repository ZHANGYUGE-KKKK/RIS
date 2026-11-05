"""Independent QAM configuration and truthful local previews; no transport."""
import math
from pathlib import Path
import tkinter as tk
from tkinter import filedialog, ttk

from ris_actions import OutputAction
from ris_frequency import active_frequency, frequency_text
from ris_patterns import compile_frame
from ris_qam_transport import make_plan, timing_ticks
from ris_qam_preamble import Preamble
from ris_mt import load_mt
from ris_qam256 import (QamCodebook, ORIENTATIONS, export_plan, integer, parse_symbol,
                        payload_bytes, read_payload, transform_cell)

QAM_TYPE = "400路独立 / 256QAM"
QAM64_TYPE = "400路独立 / 64QAM"
UNIFORM_TYPE = "400路统一MT"
SOURCES = {"固定符号": "fixed", "十六进制字节序列": "hex", "二进制文件": "file", "测试序列00–FF": "sweep"}


class QamPage:
    def __init__(self, app, parent, order=256):
        self.order, self.label = order, f"{order}QAM"
        self.sources = dict(SOURCES) if order == 256 else {**{k:v for k,v in SOURCES.items() if v != "sweep"}, "测试序列00–3F": "sweep"}
        self.app, self.alive, self.book = app, True, None
        self.default_path = Path(__file__).resolve().parents[2] / "QAM_RULES/256QAM/ris_256qam_codebook_0deg.zip"
        if order == 64:
            self.default_path = Path(__file__).resolve().parents[2] / "QAM_RULES/64QAM/ris_64qam_64slice_codebook"
        self.redraw_timer = None
        self.file_bytes = None
        self.direction = tk.StringVar(value="0 · 0°")
        self.symbol = tk.StringVar(value="00")
        self.slot = tk.StringVar(value="0")
        self.row, self.column = tk.StringVar(value="1"), tk.StringVar(value="1")
        self.source = tk.StringVar(value="固定符号")
        self.sequence = tk.StringVar(value="00 11 22 33 44 55 66 77 88 99 AA BB CC DD EE FF" if order == 256 else "00 01 07 08 1B 3F")
        self.repeats = tk.StringVar(value="3" if order == 256 else "1")
        self.loop = tk.BooleanVar(value=True)
        self.action = tk.StringVar(value="play")
        self.preamble_enabled = tk.BooleanVar(value=False)
        self.preamble_rows = ()
        self.preamble_name = ""
        self.preamble_text = tk.StringVar(value="未启用前导码。加载后，每帧先播放前导码，再播放QAM数据。")
        self.source_timing_label = "码本周期 / 边沿量化" if order == 64 else "码本原速（严格校验）"
        self.timing_mode = tk.StringVar(value=self.source_timing_label)
        self.slot_ns = tk.StringVar(value="200")
        self.loaded_text = tk.StringVar(value="先导入码本目录或ZIP，也可直接加载本项目的0°码本。")
        self.payload_text = tk.StringVar(value="")
        self.file_text = tk.StringVar(value="尚未加载数据文件")
        self.grid_title = tk.StringVar(value="码本空间 · 状态0/1预览")
        self.pwm_text = tk.StringVar()
        self.compatibility = tk.StringVar()
        self.notice = tk.StringVar(value="本页只配置。静态核线经总按钮下发；连续播放需QAM1配套BIT/ELF，时序通过后经总按钮上传并启动。")
        self.frame = ttk.Frame(parent)
        self.frame.pack(fill="both", expand=True)
        self._build()
        for variable in (self.direction, self.symbol, self.slot, self.row, self.column, self.source,
                         self.sequence, self.repeats, self.loop, self.action, self.timing_mode, self.slot_ns, self.preamble_enabled):
            variable.trace_add("write", lambda *_: self.request_refresh())
        self.update_state()

    def _build(self):
        importer = ttk.LabelFrame(self.frame, text=f"{self.label}码本", padding=8)
        importer.pack(fill="x", pady=(0, 8))
        buttons = ttk.Frame(importer)
        buttons.pack(fill="x")
        for text, command in (("导入码本目录", self.choose_directory), ("导入码本ZIP", self.choose_zip),
                              ("加载本项目0°码本", lambda: self.load(self.default_path)),
                              ("方向与极性设置", self.app.open_qam_settings)):
            ttk.Button(buttons, text=text, command=command).pack(side="left", padx=(0, 6))
        ttk.Label(importer, textvariable=self.loaded_text, wraplength=1260, foreground="#315b80").pack(anchor="w", pady=(6, 0))
        footer = ttk.Frame(self.frame)
        footer.pack(side="bottom", fill="x", pady=(6, 0))
        action_bar = ttk.Frame(footer)
        action_bar.pack(fill="x")
        ttk.Label(action_bar, text="待应用操作：").pack(side="left")
        for value, text in (("play", "连续播放"), ("static", "静态码片核线"), ("stop", "停止 / 保持")):
            ttk.Radiobutton(action_bar, text=text, variable=self.action, value=value).pack(side="left", padx=5)
        self.export_button = ttk.Button(action_bar, text="导出来源配置包", command=self.export)
        self.export_button.pack(side="right")
        ttk.Label(footer, textvariable=self.notice, wraplength=1320, foreground="#245c85").pack(anchor="w", pady=(5, 0))
        self.tabs = ttk.Notebook(self.frame)
        self.tabs.pack(fill="both", expand=True)
        preview, configuration, compatibility = [ttk.Frame(self.tabs, padding=8) for _ in range(3)]
        self.tabs.add(preview, text="星座 / PWM / 阵列预览")
        self.tabs.add(configuration, text="发送参数")
        self.tabs.add(compatibility, text="兼容性与映射")
        self._build_preview(preview)
        self._build_configuration(self._scrollable(configuration))
        compatibility = self._scrollable(compatibility)
        ttk.Label(compatibility, textvariable=self.compatibility, wraplength=1050, justify="left").pack(anchor="w", pady=10)
        ttk.Label(compatibility, text="方向和极性需按实物核对，静态码片仍需完整400路映射。\n"
                  "码本状态与GPIO位序在总下发时转换；预览、导出和设置修改不会改变当前运行。\n"
                  "离线ZIP用于保存来源配置；总按钮将编译并分块上传QAM1表，旧固件不会接受独立播放。",
                  wraplength=1050, justify="left", style="Muted.TLabel").pack(anchor="w", pady=12)
        ttk.Button(compatibility, text="打开方向与极性设置", command=self.app.open_qam_settings).pack(anchor="w", pady=5)
        ttk.Button(compatibility, text="打开FPC—RIS映射", command=self.app.open_mapping).pack(anchor="w", pady=5)

    def _scrollable(self, parent):
        viewport = ttk.Frame(parent)
        viewport.pack(fill="both", expand=True)
        canvas = tk.Canvas(viewport, background="#f4f6f9", highlightthickness=0, height=380)
        scroll = ttk.Scrollbar(viewport, orient="vertical", command=canvas.yview)
        scroll.pack(side="right", fill="y")
        canvas.configure(yscrollcommand=scroll.set)
        canvas.pack(side="left", fill="both", expand=True)
        content = ttk.Frame(canvas)
        item = canvas.create_window(0, 0, anchor="nw", window=content)
        content.bind("<Configure>", lambda _: canvas.configure(scrollregion=canvas.bbox("all")))
        canvas.bind("<Configure>", lambda event: canvas.itemconfigure(item, width=event.width))
        canvas.bind("<Button-4>", lambda _: canvas.yview_scroll(-2, "units"))
        canvas.bind("<Button-5>", lambda _: canvas.yview_scroll(2, "units"))
        return content

    def _build_preview(self, parent):
        controls = ttk.Frame(parent)
        controls.pack(fill="x", pady=(0, 8))
        ttk.Label(controls, text="方向").pack(side="left")
        self.direction_box = ttk.Combobox(controls, textvariable=self.direction, values=(), state="readonly", width=12)
        self.direction_box.pack(side="left", padx=(5, 12))
        ttk.Label(controls, text="符号HEX").pack(side="left")
        ttk.Entry(controls, textvariable=self.symbol, width=5).pack(side="left", padx=(5, 12))
        ttk.Label(controls, text="时间片q").pack(side="left")
        self.slot_box = ttk.Spinbox(controls, from_=0, to=255, textvariable=self.slot, width=6)
        self.slot_box.pack(side="left", padx=5)
        self.scale = ttk.Scale(controls, from_=0, to=255, command=self._slide, length=170)
        self.scale.pack(side="left", padx=(2, 12))
        ttk.Label(controls, text="码本单元 行/列").pack(side="left")
        for variable in (self.row, self.column):
            ttk.Spinbox(controls, from_=1, to=20, textvariable=variable, width=4).pack(side="left", padx=4)
        panes = ttk.Panedwindow(self._scrollable(parent), orient="horizontal", height=380)
        panes.pack(fill="both", expand=True)
        left = ttk.Frame(panes, width=340)
        panes.add(left, weight=0)
        left.rowconfigure(1, weight=3)
        left.rowconfigure(3, weight=2)
        left.columnconfigure(0, weight=1)
        ttk.Label(left, text=f"目标{self.label}星座 · 非接收测量").grid(row=0, column=0, sticky="w")
        self.constellation = tk.Canvas(left, width=330, height=190, background="#ffffff", highlightthickness=0)
        self.constellation.grid(row=1, column=0, sticky="nsew", pady=4)
        self.constellation.bind("<Button-1>", self.pick_symbol)
        ttk.Label(left, textvariable=self.pwm_text, wraplength=330).grid(row=2, column=0, sticky="w", pady=4)
        self.pwm = tk.Canvas(left, width=330, height=115, background="#ffffff", highlightthickness=0)
        self.pwm.grid(row=3, column=0, sticky="nsew")
        right = ttk.Frame(panes, padding=(12, 0, 0, 0))
        panes.add(right, weight=1)
        ttk.Label(right, textvariable=self.grid_title).pack(anchor="w")
        self.grid = tk.Canvas(right, width=600, height=340, background="#ffffff", highlightthickness=0)
        self.grid.pack(fill="both", expand=True, pady=(4, 0))
        self.grid.bind("<Button-1>", self.pick_cell)
        for canvas in (self.constellation, self.pwm, self.grid):
            canvas.bind("<Configure>", lambda _: self.request_refresh())

    def _build_configuration(self, parent):
        form = ttk.LabelFrame(parent, text="发送数据与重复方式", padding=18)
        form.pack(fill="x")
        ttk.Label(form, text="数据源").grid(row=0, column=0, sticky="w", pady=7)
        ttk.Combobox(form, textvariable=self.source, values=list(self.sources), state="readonly", width=24).grid(row=0, column=1, sticky="w", padx=12)
        ttk.Label(form, text=f"每字节一个符号ID，范围00–{self.order-1:02X}；固定符号由预览区选择。", style="Muted.TLabel").grid(row=0, column=2, sticky="w")
        ttk.Label(form, text="HEX序列").grid(row=1, column=0, sticky="w", pady=7)
        ttk.Entry(form, textvariable=self.sequence, width=60).grid(row=1, column=1, columnspan=2, sticky="ew", padx=12)
        ttk.Label(form, text="二进制数据").grid(row=2, column=0, sticky="w", pady=7)
        ttk.Button(form, text="加载二进制文件", command=self.choose_payload).grid(row=2, column=1, sticky="w", padx=12)
        ttk.Label(form, textvariable=self.file_text, wraplength=550).grid(row=2, column=2, sticky="w")
        ttk.Label(form, text="每符号PWM周期数K").grid(row=3, column=0, sticky="w", pady=7)
        ttk.Spinbox(form, from_=1, to=1000000, textvariable=self.repeats, width=12).grid(row=3, column=1, sticky="w", padx=12)
        ttk.Checkbutton(form, text="循环整帧（含前导码）；取消则播放一次", variable=self.loop).grid(row=3, column=2, sticky="w")
        ttk.Label(form, textvariable=self.payload_text, wraplength=1100, foreground="#315b80").grid(row=4, column=0, columnspan=3, sticky="w", pady=(16, 0))
        ttk.Label(form, text="播放时序").grid(row=5, column=0, sticky="w", pady=7)
        ttk.Combobox(form, textvariable=self.timing_mode,
                     values=(self.source_timing_label, "低速数字核线（明确改速）"),
                     state="readonly", width=29).grid(row=5, column=1, sticky="w", padx=12)
        ttk.Label(form, text="低速核线片长 / ns").grid(row=6, column=0, sticky="w", pady=7)
        ttk.Entry(form, textvariable=self.slot_ns, width=14).grid(row=6, column=1, sticky="w", padx=12)
        ttk.Label(form, text="例如200 ns；仅在低速核线模式生效。实际PWM和速率见上方预览。",
                  wraplength=550).grid(row=6, column=2, sticky="w")
        form.columnconfigure(2, weight=1)
        prefix = ttk.LabelFrame(parent, text="前导码MT表 · 400路统一控制", padding=12)
        prefix.pack(fill="x", pady=(12, 0))
        buttons = ttk.Frame(prefix)
        buttons.pack(fill="x")
        ttk.Checkbutton(buttons, text="启用前导码", variable=self.preamble_enabled).pack(side="left")
        ttk.Button(buttons, text="加载前导码MT表", command=self.choose_preamble).pack(side="left", padx=12)
        ttk.Button(buttons, text="清除前导码", command=self.clear_preamble).pack(side="left")
        ttk.Label(prefix, textvariable=self.preamble_text, wraplength=1050, foreground="#315b80").pack(anchor="w", pady=6)
        self.preamble_preview = ttk.Frame(prefix)
        self.preamble_preview.pack(fill="x")
        self.preamble_table = ttk.Treeview(self.preamble_preview, columns=("row", "m", "actual"), show="headings", height=4)
        for key, title, width in (("row", "周期", 70), ("m", "输入M / %（T必须为0）", 230), ("actual", "实际高电平占比 / %", 230)):
            self.preamble_table.heading(key, text=title)
            self.preamble_table.column(key, width=width, stretch=True)
        self.preamble_table.pack(side="left", fill="x", expand=True)
        scroll = ttk.Scrollbar(self.preamble_preview, orient="vertical", command=self.preamble_table.yview)
        scroll.pack(side="right", fill="y")
        self.preamble_table.configure(yscrollcommand=scroll.set)
        ttk.Label(prefix, text="格式沿用(M,T);，最多10行，每行一个PWM周期，K仅作用于QAM数据。\n"
                  "前导码采用同一时间片网格，表中显示量化后的实际占空比；每次整帧循环均包含前导码。",
                  wraplength=1050, style="Muted.TLabel").pack(anchor="w", pady=(6, 0))
        ttk.Label(parent, text="来源参数保留；原速模式要求精确兼容。明确选择低速核线后，按设置片长改变实际播放频率。\n"
                  "改速只用于数字核线，源模型EVM不随之验收。当前QAM1每包最多4096字节。所有编辑仅配置下一次应用。",
                  wraplength=1120, justify="left", style="Muted.TLabel").pack(anchor="w", pady=18)

    def choose_preamble(self):
        path = filedialog.askopenfilename(parent=self.app.root, title="加载前导码MT表", filetypes=[("MT表", "*.txt *.csv *.mt"), ("所有文件", "*")])
        if path:
            self.load_preamble(path)

    def load_preamble(self, path):
        try:
            rows = load_mt(path)
            Preamble.compile(rows, self.book.slots if self.book else 256)
        except (OSError, ValueError) as error:
            self.notice.set(f"前导码未载入，保留原配置：{error}")
            return False
        self.preamble_rows, self.preamble_name = rows, Path(path).name
        self.preamble_enabled.set(True)
        self.notice.set("前导码已载入配置快照；当前输出保持，点击总下发才应用。")
        self.request_refresh()
        return True

    def clear_preamble(self):
        self.preamble_rows, self.preamble_name = (), ""
        self.preamble_enabled.set(False)
        self.request_refresh()

    def _preamble(self):
        if not self.preamble_enabled.get():
            return ()
        if not self.preamble_rows:
            raise ValueError("已启用前导码，请先加载前导码MT表")
        Preamble.compile(self.preamble_rows, self.book.slots if self.book else 256)
        return self.preamble_rows

    def refresh_preamble(self):
        self.preamble_table.delete(*self.preamble_table.get_children())
        if not self.preamble_rows:
            self.preamble_preview.pack_forget()
            self.preamble_text.set("未加载前导码。最多10个周期，所有延时T必须为0。")
            return
        if not self.preamble_preview.winfo_manager():
            self.preamble_preview.pack(fill="x")
        plan = Preamble.compile(self.preamble_rows, self.book.slots if self.book else 256)
        for i, ((m, _), width) in enumerate(zip(plan.rows, plan.widths), 1):
            self.preamble_table.insert("", "end", values=(i, str(m), f"{width*100/plan.slots:.6g}"))
        self.preamble_text.set(f"{self.preamble_name} · {len(plan.rows)}个周期 · {'已启用' if self.preamble_enabled.get() else '未启用'} · 与QAM共用周期和边界")

    def choose_directory(self):
        picked = filedialog.askdirectory(parent=self.app.root, title=f"选择{self.label}码本目录")
        if picked:
            self.load(picked)

    def choose_zip(self):
        picked = filedialog.askopenfilename(parent=self.app.root, title=f"选择{self.label}码本ZIP", filetypes=[("码本ZIP", "*.zip")])
        if picked:
            self.load(picked)

    def load(self, path):
        try:
            candidate = QamCodebook.load(path)
            if candidate.order != self.order:
                raise ValueError(f"本页只接受{self.label}码本，请切换对应控制类型")
        except ValueError as error:
            self.notice.set(str(error) + "；保留当前码本。")
            return False
        self.book = candidate
        self.direction_box.configure(values=[f"{i} · {angle:g}°" for i, angle in enumerate(candidate.angles)])
        self.direction.set(f"0 · {candidate.angles[0]:g}°")
        self.slot_box.configure(to=candidate.slots - 1)
        self.scale.configure(to=candidate.slots - 1)
        self.slot.set("0")
        self.repeats.set(str(candidate.default_repeats))
        self.loaded_text.set(f"{candidate.origin.name} · {len(candidate.angles)}个方向 · 20×20 · {candidate.slots}片/周期 · "
                             f"PWM {frequency_text(candidate.pwm_hz)} · 6文件校验及全部图案校验通过")
        self.notice.set("码本已载入，当前输出保持。可预览、配置并导出；静态码片经总按钮应用。")
        self.request_refresh()
        return True

    def choose_payload(self):
        picked = filedialog.askopenfilename(parent=self.app.root, title="选择待发原始字节文件", filetypes=[("二进制数据", "*.bin *.dat"), ("所有文件", "*")])
        if picked:
            self.load_payload(picked)

    def load_payload(self, path):
        try:
            data = read_payload(path)
            if self.order == 64:
                payload_bytes("file", "00", "", data, self.order)
        except (OSError, ValueError) as error:
            self.notice.set(f"数据文件未载入，保留原数据：{error}")
            return False
        self.file_bytes = data
        self.file_text.set(f"{Path(path).name} · {len(data):,}字节 · 已读取配置快照")
        self.source.set("二进制文件")
        self.request_refresh()
        return True

    def _selection(self):
        if not self.book:
            raise ValueError(f"请先导入{self.label}码本")
        try:
            direction = int(self.direction.get().split("·")[0])
            slot, row, column = int(self.slot.get()), int(self.row.get()) - 1, int(self.column.get()) - 1
        except ValueError:
            raise ValueError("方向、时间片和单元行列需要有效整数") from None
        symbol = parse_symbol(self.symbol.get(), self.order)
        self.book.frame(direction, symbol, slot)
        integer(row, 0, 19, "码本单元行")
        integer(column, 0, 19, "码本单元列")
        return direction, symbol, slot, row, column

    def _payload(self):
        try:
            repeats = int(self.repeats.get())
        except ValueError:
            raise ValueError("K需要是1–1000000的整数") from None
        integer(repeats, 1, 1000000, "K")
        return payload_bytes(self.sources.get(self.source.get()), self.symbol.get(), self.sequence.get(), self.file_bytes, self.order), repeats

    def prepare_action(self):
        if self.action.get() == "stop":
            return OutputAction("command", "STOP", "停止 / 保持当前输出")
        if self.action.get() == "play":
            direction, _symbol, _slot, _row, _column = self._selection()
            orientation, high = self.app.qam_wiring()
            data, repeats = self._payload()
            plan = make_plan(self.book, self.app.mapping_page.model.copy(), direction, orientation, high,
                             repeats, self.loop.get(), data, self._timing(), self.slot_ns.get(), self._preamble())
            def completed(reply, error):
                if error:
                    self.notice.set("结果未确认：" + str(error))
                elif reply and reply.get("qam_crc") == plan.crc and reply.get("qam_status", 0)&1:
                    self.notice.set(f"板端已确认：包CRC {plan.crc:08X}，实际PWM {frequency_text(plan.actual_pwm_hz)}，QAM每符号K={plan.data_repeats}。")
                else:
                    self.notice.set("已取消上传并停止；保持图案以板端状态为准。")
            return OutputAction("qam", plan, self._play_summary(plan.actual_pwm_hz, len(data), repeats), completed,
                                self.app.mapping_page.model.document(), "qam_play")
        direction, symbol, slot, _row, _column = self._selection()
        orientation, high = self.app.qam_wiring()
        image = compile_frame(self.book.pattern(direction, symbol, slot, orientation, high), self.app.mapping_page.model)
        label = f"静态码片 · {self.book.angles[direction]:g}° · 0x{symbol:02X} · q={slot}"
        def completed(reply, error):
            confirmed = not error and reply and reply["ok"] and not reply["errors"] and reply["oe"] and not reply["blink_ms"] and not active_frequency(reply) and reply["image"].upper() == image.hex().upper()
            self.notice.set(f"已确认{label}；当前为静态保持，非{self.label}播放。" if confirmed else "静态码片结果未确认，请检查连接和板端状态。")
        return OutputAction("command", "FRAME " + image.hex().upper(), label, completed,
                            self.app.mapping_page.model.document(), "qam64_static" if self.order == 64 else "qam_static")

    def _timing(self):
        return "bench" if self.timing_mode.get() == "低速数字核线（明确改速）" else "source"

    def _play_summary(self, actual, count, repeats):
        mode = "低速核线" if self._timing() == "bench" else "原速"
        prefix = f"前导{len(self._preamble())}周期 + " if self.preamble_enabled.get() else ""
        return f"{prefix}{self.label} {mode} · {count}字节 · K={repeats} · PWM {frequency_text(actual)} · {'整帧循环' if self.loop.get() else '单次'}"

    def preview_action(self):
        if self.action.get() != "play":
            return self.prepare_action()
        self._selection()
        self.app.qam_wiring()
        data, repeats = self._payload()
        if len(data)>4096:
            raise ValueError("当前QAM1一次最多4096字节，不支持边播放边上传")
        ticks = timing_ticks(self.book, self._timing(), self.slot_ns.get())
        rows = self._preamble()
        if rows and len(rows)+len(data)*repeats > 4096*(65535//self.book.slots):
            raise ValueError("前导码与数据合帧超出现有播放器容量；请缩短数据或减小K")
        return OutputAction("qam", None, self._play_summary(self.book.pwm_hz if self.order == 64 and self._timing() == "source" else 300000000/(ticks*self.book.slots), len(data), repeats))

    def export(self, path=None):
        try:
            direction, _symbol, _slot, _row, _column = self._selection()
            orientation, high = self.app.qam_wiring()
            data, repeats = self._payload()
            rows = self._preamble()
            # Validate before presenting a save dialog.
            compile_frame(self.book.pattern(direction, 0, 0, orientation, high), self.app.mapping_page.model)
            if path is None:
                path = filedialog.asksaveasfilename(parent=self.app.root, title="导出来源时序的离线配置包",
                    initialdir=self.app.qam_data_dir if self.app.qam_data_dir.exists() else Path(__file__).resolve().parent,
                    initialfile=f"qam{self.order}_playback_plan.zip", defaultextension=".zip", filetypes=[("播放配置包", "*.zip")])
                if not path:
                    return False
            manifest = export_plan(path, self.book, self.app.mapping_page.model.copy(), direction,
                                   orientation, high, repeats, self.loop.get(), data, preamble_rows=rows)
            prefix_note = f"、前导码{len(rows)}周期" if rows else ""
            self.notice.set(f"已导出来源时序配置包：{manifest['dictionary_frames']}幅图案、{manifest['event_records']}个时段、{len(data)}字节数据{prefix_note}；不含低速核线改速，未发送到板卡。")
            return True
        except (OSError, ValueError) as error:
            self.notice.set(f"未导出：{error}")
            return False

    def _slide(self, value):
        slot = str(int(round(float(value))))
        if self.slot.get() != slot:
            self.slot.set(slot)

    def request_refresh(self):
        if self.alive and self.redraw_timer is None:
            self.redraw_timer = self.frame.after_idle(self.refresh)

    def update_state(self):
        if not self.alive:
            return
        self.export_button.configure(state="normal" if self.book else "disabled")
        self.compatibility.set(self._compatibility())

    def _compatibility(self):
        text = ["QAM1：总按钮先核对板端能力，再分块上传、校验完整包并启动；可单次或循环。",
                "上传中选择停止并点击总按钮可取消；修改草稿、切页和导出ZIP不更新实际输出。"]
        reply = self.app.latest or {}
        text.append("已连接QAM1固件。" if reply.get("qam_supported") else "尚未确认板端QAM1能力；需新副本配套BIT与ELF。")
        if self.book:
            book = self.book
            slot_ns = 1e9 / (book.pwm_hz * book.slots)
            text += [f"码本：PWM {frequency_text(book.pwm_hz)}，每片{slot_ns:.6g} ns；独立QAM1每片至少200 ns。",
                     f"300 MHz时钟下每片={300000000 / (book.pwm_hz * book.slots):.9g}个时钟；这里不做静默取整。"]
            try:
                direction = int(self.direction.get().split("·")[0])
                evm = book.metadata["directions"][direction].get("evm_equalized_percent")
                if evm is not None:
                    text.append(f"源包模型均衡EVM：{evm:.6g}%（非实测，图中显示目标星座）。")
            except (ValueError, IndexError, TypeError):
                pass
        if self.order == 64:
            text = [line for line in text if "独立QAM1每片" not in line and "不做静默取整" not in line]
            text += ["64QAM原速使用300 MHz边沿计时：周期保持整数tick，边沿按最近tick量化；100 MHz SHCP不变。",
                     "160 kHz、64片：每周期1875 tick；片长29或30 tick，边沿误差不超过1.667 ns。需64QAM配套BIT/ELF。"]
        try:
            orientation, high = self.app.qam_wiring()
            text.append(f"已确认方向：{ORIENTATIONS[orientation]}；状态1→驱动{'高' if high else '低'}。")
        except ValueError as error:
            text.append(str(error))
        if self.app.mapping_page:
            mapping = self.app.mapping_page.model
            text.append(f"当前FPC映射：{mapping.count()}/400路，{len(mapping.ports)}/10个接口。")
        return "\n\n".join(text)

    def refresh(self):
        self.redraw_timer = None
        if not self.alive:
            return
        self.update_state()
        try:
            self.refresh_preamble()
        except ValueError as error:
            self.preamble_text.set(str(error))
        try:
            direction, symbol, slot, row, column = self._selection()
            self.draw_constellation(symbol)
            self.draw_pwm(direction, symbol, slot, row * 20 + column)
            self.draw_grid(direction, symbol, slot, row, column)
            self.scale.set(slot)
        except ValueError as error:
            for canvas in (self.constellation, self.pwm, self.grid):
                canvas.delete("all")
                canvas.create_text(15, 25, anchor="w", text=str(error), fill="#617287")
        try:
            if self.book:
                data, repeats = self._payload()
                source_text = f"来源 {self.book.pwm_hz / repeats:,.3f} Baud"
                try:
                    ticks = timing_ticks(self.book, self._timing(), self.slot_ns.get())
                    actual = self.book.pwm_hz if self.order == 64 and self._timing() == "source" else 300000000/(ticks*self.book.slots)
                    timing_text = f"实际PWM {frequency_text(actual)} · {actual / repeats:,.3f} Baud · {self.book.bits_per_symbol*actual/repeats:,.3f} bit/s"
                    if self.order == 64 and self._timing() == "source":
                        timing_text += " · 边沿量化≤1.667 ns"
                except ValueError as error:
                    actual = self.book.pwm_hz
                    timing_text = str(error)
                preamble = self._preamble()
                duration = (len(preamble) + len(data) * repeats) / actual
                duration_text = f"{duration * 1e6:.6g} µs" if duration < .001 else (f"{duration * 1000:.6g} ms" if duration < 1 else f"{duration:.6g} s")
                lead = f"前导{len(preamble)}周期 + " if preamble else ""
                average = f" · 含前导码帧平均{self.book.bits_per_symbol*len(data)/duration:,.3f} bit/s" if preamble else ""
                self.payload_text.set(f"{lead}{len(data):,}个符号 · K={repeats} · {source_text} · {timing_text}{average} · 一帧{duration_text} · {'整帧循环' if self.loop.get() else '播放一次'}")
        except ValueError as error:
            self.payload_text.set(str(error))
        self.app.refresh_pending()

    def draw_constellation(self, selected):
        canvas = self.constellation
        canvas.delete("all")
        w, h = max(100, canvas.winfo_width()), max(80, canvas.winfo_height())
        cx, cy, scale = w / 2, h / 2, min(w, h) * .56
        canvas.create_line(15, cy, w - 15, cy, fill="#d3dce8")
        canvas.create_line(cx, 12, cx, h - 12, fill="#d3dce8")
        self.point_hits = []
        for index, item in enumerate(self.book.symbols):
            x, y = cx + item.real * scale, cy - item.imag * scale
            radius, color = (4, "#e87924") if index == selected else (2, "#2563eb")
            canvas.create_oval(x - radius, y - radius, x + radius, y + radius, fill=color, outline="")
            self.point_hits.append((x, y, index))
        item = self.book.symbols[selected]
        canvas.create_text(8, 8, anchor="nw", text=f"0x{selected:02X} · I={item.i}, Q={item.q}", fill="#23354a")

    def pick_symbol(self, event):
        if self.book and getattr(self, "point_hits", None):
            x, y, symbol = min(self.point_hits, key=lambda item: (item[0] - event.x)**2 + (item[1] - event.y)**2)
            if (x - event.x)**2 + (y - event.y)**2 <= 100:
                self.symbol.set(f"{symbol:02X}")

    def draw_pwm(self, direction, symbol, slot, unit):
        canvas, book = self.pwm, self.book
        canvas.delete("all")
        width, start = book.pulse(direction, symbol, unit)
        self.pwm_text.set(f"码本C状态 · 单元{unit} · M={width * 100 / book.slots:.4g}% / T={start * 100 / book.slots:.4g}%")
        w, h = max(100, canvas.winfo_width()), max(60, canvas.winfo_height())
        left, right, top, bottom = 24, w - 12, 16, max(34, h - 28)
        points = []
        def y(q):
            return top if (q - start) % book.slots < width else bottom
        for q in range(book.slots * 2):
            x0 = left + q / (book.slots * 2) * (right - left)
            x1 = left + (q + 1) / (book.slots * 2) * (right - left)
            points.extend((x0, y(q), x1, y(q)))
        canvas.create_line(*points, fill="#168b79", width=2)
        marker = left + slot / (book.slots * 2) * (right - left)
        canvas.create_line(marker, 10, marker, bottom + 5, fill="#e87924", dash=(3, 2))
        for q, label in ((0, "0"), (book.slots, "1T"), (book.slots * 2, "2T")):
            canvas.create_text(left + q / (book.slots * 2) * (right - left), h - 12, text=label, fill="#617287")
        canvas.create_text(8, top, text="1", fill="#617287")
        canvas.create_text(8, bottom, text="0", fill="#617287")

    def draw_grid(self, direction, symbol, slot, row, column):
        canvas = self.grid
        canvas.delete("all")
        orientation, high, confirmed = "identity", True, False
        try:
            orientation, high = self.app.qam_wiring()
            confirmed = True
        except ValueError:
            pass
        pattern = self.book.pattern(direction, symbol, slot, orientation, high)
        focus = transform_cell(row, column, orientation)
        self.grid_title.set(("RIS实物方向 · 绿色为驱动高（非电压回读）" if confirmed else "码本空间 · 绿色为状态1；实物方向/极性待确认") +
                            f" · q={slot}/{self.book.slots - 1}")
        w, h = max(100, canvas.winfo_width()), max(100, canvas.winfo_height())
        size = max(3, min((w - 55) / 20, (h - 35) / 20))
        x0, y0 = max(30, (w - 20 * size) / 2), 25
        self.grid_geometry = x0, y0, size, orientation
        for index in range(20):
            canvas.create_text(x0 + (index + .5) * size, 12, text=str(index + 1), fill="#617287", font=("sans", 8))
            canvas.create_text(x0 - 16, y0 + (index + .5) * size, text=str(index + 1), fill="#617287", font=("sans", 8))
        for r, line in enumerate(pattern.rows):
            for c, value in enumerate(line):
                focused = (r, c) == focus
                canvas.create_rectangle(x0 + c * size, y0 + r * size, x0 + (c + 1) * size, y0 + (r + 1) * size,
                    fill="#36b59b" if value == "1" else "#eef3f9", outline="#e87924" if focused else "#c7d3e3", width=2 if focused else 1)

    def pick_cell(self, event):
        if not self.book or not hasattr(self, "grid_geometry"):
            return
        x0, y0, size, orientation = self.grid_geometry
        row, column = int(math.floor((event.y - y0) / size)), int(math.floor((event.x - x0) / size))
        if 0 <= row < 20 and 0 <= column < 20:
            unit = next(unit for unit in range(400) if transform_cell(*divmod(unit, 20), orientation) == (row, column))
            self.row.set(str(unit // 20 + 1))
            self.column.set(str(unit % 20 + 1))

    def shutdown(self):
        self.alive = False
        if self.redraw_timer is not None:
            self.frame.after_cancel(self.redraw_timer)
            self.redraw_timer = None
