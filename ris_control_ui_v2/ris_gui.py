#!/usr/bin/env python3
"""RIS console v2: isolated configuration pages and one explicit output gate."""
import argparse
from pathlib import Path
import queue
import threading
import time
import tkinter as tk
from tkinter import ttk
from tkinter.scrolledtext import ScrolledText

from ris_actions import OutputAction, confirmed_status, describe_command
from ris_client import DEFAULT_HOST, DEFAULT_PORT, RisClient
from ris_frequency import frequency_text, plan_frequency

FEATURES = {"board": "全板控制", "mt": "MT时域控制", "patterns": "图案切换控制", "settings": "全板设置"}


class RisGui:
    def __init__(self, root, host=DEFAULT_HOST, port=DEFAULT_PORT, pattern_storage=None, mapping_storage=None):
        self.root = root
        self.connected = self.busy = self.closed = self.mt_uploading = False
        self.mt_cancel = threading.Event()
        self.latest = self.applied_action = self.inflight_action = self.playback_plan = None
        self._write_authorized = False
        self.tasks, self.results = queue.Queue(), queue.Queue()
        self.pending_callback = None
        self.mapping_page = self.manual = self.pattern_page = self.mt_controls = None
        self.current_page = "home"
        self.staged = {}
        self.byte_scope = None
        self.last_board_mode = "stop"
        self.confirmed_time = ""
        self.host = tk.StringVar(value=host)
        self.port = tk.StringVar(value=str(port))
        self.feature = tk.StringVar(value="请选择功能")
        self.board_mode = tk.StringVar(value="stop")
        self.settings_mode = tk.StringVar(value="none")
        self.settings_view = tk.StringVar(value="输出设置")
        self.period = tk.StringVar(value="1000")
        self.board_frequency = tk.StringVar(value="5")
        self.board_unit = tk.StringVar(value="M")
        self.fast_value = tk.StringVar(value="5")
        self.fast_unit = tk.StringVar(value="M")
        self.mt_action = tk.StringVar(value="play")
        self.chip = tk.StringVar(value="1")
        self.hex_value = tk.StringVar(value="00")
        self.selected = tk.StringVar(value="第 1 片 · 实物 U4 · 第 1 组")
        self.bits = [tk.IntVar(value=0) for _ in range(8)]
        self.notice = tk.StringVar(value="未连接。电脑有线网卡：192.168.1.20/24；板卡：192.168.1.11")
        self.state = tk.StringVar(value="等待连接")
        self.status_title = tk.StringVar(value="未连接")
        self.status_detail = tk.StringVar(value="工作状态未确认")
        self.status_meta = tk.StringVar(value="等待板端状态")
        self.pending_text = tk.StringVar(value="选择功能并配置参数")
        self.frequency_preview = tk.StringVar()
        self.fast_notice = tk.StringVar()
        self.page_hint = tk.StringVar()
        self._build(pattern_storage, mapping_storage)
        for variable in (self.board_mode, self.period, self.board_frequency, self.board_unit,
                         self.settings_mode, self.mt_action, self.fast_value, self.fast_unit, self.hex_value, self.chip):
            variable.trace_add("write", lambda *_: self.refresh_pending())
        threading.Thread(target=self._worker, daemon=True).start()
        self.receive_timer = root.after(50, self._receive)
        self.poll_timer = root.after(1000, self._poll)
        root.protocol("WM_DELETE_WINDOW", self.close)

    def _build(self, pattern_storage, mapping_storage):
        root = self.root
        root.title("RIS 控制台 v2 · 统一下发")
        width = min(1460, root.winfo_screenwidth() - 50)
        height = min(980, root.winfo_screenheight() - 80)
        root.geometry(f"{width}x{height}+20+20")
        root.minsize(min(1180, width), min(760, height))
        style = ttk.Style(root)
        style.theme_use("clam")
        style.configure("TFrame", background="#f4f6f9")
        style.configure("TLabel", background="#f4f6f9", foreground="#23354a")
        for control in ("TRadiobutton", "TCheckbutton"):
            style.configure(control, background="#f4f6f9", foreground="#23354a")
            style.map(control, background=[("active", "#e8eef7")])
        style.configure("TLabelframe", background="#f4f6f9")
        style.configure("TLabelframe.Label", background="#f4f6f9", foreground="#23354a")
        style.configure("TButton", padding=(10, 6))
        style.configure("Title.TLabel", font=("sans", 22, "bold"))
        style.configure("Muted.TLabel", foreground="#617287")
        style.configure("Apply.TButton", font=("sans", 16, "bold"), padding=(16, 18), background="#2563eb", foreground="white")
        style.map("Apply.TButton", background=[("disabled", "#d8dee8"), ("active", "#1d4ed8")], foreground=[("disabled", "#7c8b9e")])
        main = ttk.Frame(root, padding=16)
        main.pack(fill="both", expand=True)
        header = ttk.Frame(main)
        header.pack(fill="x")
        header.columnconfigure(0, weight=1)
        identity = ttk.Frame(header)
        identity.grid(row=0, column=0, sticky="nsew", padx=(0, 16))
        ttk.Label(identity, text="RIS 控制台", style="Title.TLabel").pack(anchor="w")
        ttk.Label(identity, text="400 路 · ZC706 · 统一配置与下发", style="Muted.TLabel").pack(anchor="w", pady=(2, 14))
        network = ttk.Frame(identity)
        network.pack(anchor="w")
        ttk.Label(network, text="IP").pack(side="left")
        self.host_entry = ttk.Entry(network, textvariable=self.host, width=16)
        self.host_entry.pack(side="left", padx=(5, 10))
        ttk.Label(network, text="端口").pack(side="left")
        self.port_entry = ttk.Entry(network, textvariable=self.port, width=6)
        self.port_entry.pack(side="left", padx=5)
        links = ttk.Frame(identity)
        links.pack(anchor="w", pady=(8, 0))
        self.connect_button = ttk.Button(links, text="连接板卡", command=self.connect)
        self.connect_button.pack(side="left")
        self.disconnect_button = ttk.Button(links, text="断开连接", command=self.disconnect)
        self.disconnect_button.pack(side="left", padx=6)
        monitor = tk.Frame(header, background="#122238", width=440, height=160, padx=18, pady=13)
        monitor.grid(row=0, column=1, sticky="nsew", padx=(0, 12))
        monitor.pack_propagate(False)
        tk.Label(monitor, text="RIS 实际工作状态", bg="#122238", fg="#93a7be", font=("sans", 10)).pack(anchor="w")
        self.monitor_title = tk.Label(monitor, textvariable=self.status_title, bg="#122238", fg="#94a3b8",
                                      font=("sans", 22, "bold"), width=23, anchor="w", justify="left", wraplength=420)
        self.monitor_title.pack(anchor="w", pady=(6, 4))
        tk.Label(monitor, textvariable=self.status_detail, bg="#122238", fg="#d7e2ef", wraplength=420,
                 justify="left", anchor="w", font=("sans", 10)).pack(anchor="w")
        tk.Label(monitor, textvariable=self.status_meta, bg="#122238", fg="#93a7be", font=("sans", 9)).pack(anchor="w", pady=(7, 0))
        output = ttk.Frame(header, width=240)
        output.grid(row=0, column=2, sticky="nsew")
        output.pack_propagate(False)
        self.apply_button = ttk.Button(output, text="下发指令", style="Apply.TButton", command=self.apply_current)
        self.apply_button.pack(fill="x")
        ttk.Label(output, text="应用当前页面的配置", style="Muted.TLabel").pack(anchor="w", pady=(6, 4))
        ttk.Label(output, textvariable=self.pending_text, foreground="#1e5c9c", wraplength=235, justify="left").pack(anchor="w")
        ttk.Label(main, textvariable=self.notice, foreground="#315b80", wraplength=1350).pack(anchor="w", pady=(10, 12))
        ttk.Separator(main).pack(fill="x")
        navigation = ttk.Frame(main)
        navigation.pack(fill="x", pady=12)
        ttk.Label(navigation, text="功能", font=("sans", 12, "bold")).pack(side="left")
        self.feature_box = ttk.Combobox(navigation, textvariable=self.feature, values=list(FEATURES.values()), state="readonly", width=21, font=("sans", 12))
        self.feature_box.pack(side="left", padx=(12, 20))
        self.feature_box.bind("<<ComboboxSelected>>", lambda _: self.show_page(next(key for key, name in FEATURES.items() if name == self.feature.get())))
        ttk.Label(navigation, textvariable=self.page_hint, style="Muted.TLabel").pack(side="left")
        self.content = ttk.Frame(main)
        self.content.pack(fill="both", expand=True)
        self.frames = {key: ttk.Frame(self.content) for key in ("home", *FEATURES)}
        self.control_frame, self.mt_frame, self.pattern_frame, self.settings_frame = [self.frames[k] for k in FEATURES]
        welcome = ttk.Frame(self.frames["home"], padding=40)
        welcome.place(relx=.5, rely=.4, anchor="center")
        ttk.Label(welcome, text="先选择功能，再配置和下发", font=("sans", 20, "bold")).pack(pady=12)
        ttk.Label(welcome, text="全板控制    /    MT时域控制    /    图案切换控制    /    全板设置", style="Muted.TLabel").pack(pady=6)
        ttk.Label(welcome, text="页面中的操作只修改配置；右上角“下发指令”应用当前页面的更新。", style="Muted.TLabel").pack(pady=6)
        self._build_settings()
        from ris_mapping_gui import MappingPage
        self.mapping_page = MappingPage(self, self.mapping_frame, mapping_storage)
        self._build_board()
        self._build_mt()
        from ris_pattern_gui import PatternPage
        self.pattern_page = PatternPage(self, self.mapping_page, self.pattern_frame, pattern_storage)
        root.bind("<Control-s>", lambda _: self.mapping_shortcut("save"))
        root.bind("<Control-z>", lambda _: self.mapping_shortcut("undo"))
        self.show_page("home")
        self._enable()

    def _build_board(self):
        self.board_modes = modes = ttk.LabelFrame(self.control_frame, text="全板工作模式", padding=16)
        modes.pack(fill="x")
        options = (("stop", "停止切换 / 保持"), ("all0", "全0 · 静态保持"), ("all1", "全1 · 静态保持"),
                   ("blink", "全0 / 全1慢速循环"), ("fast", "全0 / 全1硬件方波"))
        for index, (value, label) in enumerate(options):
            ttk.Radiobutton(modes, text=label, variable=self.board_mode, value=value).grid(row=index // 3, column=index % 3, sticky="w", padx=(0, 30), pady=7)
        timing = ttk.Frame(modes)
        timing.grid(row=2, column=0, columnspan=3, sticky="ew", pady=(12, 0))
        ttk.Label(timing, text="慢速循环 · 每次切换间隔 ms").pack(side="left")
        ttk.Spinbox(timing, from_=100, to=60000, increment=100, textvariable=self.period, width=9).pack(side="left", padx=(10, 25))
        ttk.Label(timing, text="硬件方波 · 完整周期频率").pack(side="left")
        ttk.Entry(timing, textvariable=self.board_frequency, width=10).pack(side="left", padx=8)
        ttk.Combobox(timing, textvariable=self.board_unit, values=("Hz", "k", "M", "G"), state="readonly", width=5).pack(side="left")
        ttk.Label(modes, textvariable=self.frequency_preview, foreground="#315b80").grid(row=3, column=0, columnspan=3, sticky="w", pady=(10, 0))
        self.show_chip_editor = tk.BooleanVar(value=False)
        self.board_toggle = ttk.Checkbutton(self.control_frame, text="切换到单元 / 芯片配置与接线检查", variable=self.show_chip_editor,
                                           command=self.toggle_chip_editor)
        self.board_toggle.pack(anchor="w", pady=12)
        self.local_controls = ttk.Frame(self.control_frame)
        self.editor = editor = ttk.LabelFrame(self.local_controls, text="芯片字节配置", padding=8)
        editor.pack(fill="x")
        ttk.Label(editor, text="芯片 1–50").grid(row=0, column=0)
        selector = ttk.Spinbox(editor, from_=1, to=50, textvariable=self.chip, width=5, command=self.select_chip)
        selector.grid(row=0, column=1, padx=8)
        selector.bind("<Return>", lambda _: self.select_chip())
        selector.bind("<FocusOut>", lambda _: self.select_chip())
        ttk.Label(editor, textvariable=self.selected).grid(row=0, column=2, columnspan=4, sticky="w", padx=8)
        ttk.Label(editor, text="HEX").grid(row=0, column=6)
        entry = ttk.Entry(editor, textvariable=self.hex_value, width=6)
        entry.grid(row=0, column=7, padx=6)
        entry.bind("<Return>", lambda _: self.hex_to_bits())
        entry.bind("<FocusOut>", lambda _: self.hex_to_bits(quiet=True))
        for bit in range(8):
            ttk.Checkbutton(editor, text=f"Q{bit}", variable=self.bits[bit], command=self.bits_to_hex).grid(row=1, column=bit, padx=7, pady=6)
        ttk.Button(editor, text="选择此芯片配置", command=lambda: self.apply_byte(False)).grid(row=0, column=8, padx=10)
        ttk.Button(editor, text="选择此5片组配置", command=lambda: self.apply_byte(True)).grid(row=1, column=8, padx=10)
        self.board = ttk.LabelFrame(self.local_controls, text="单元配置 · 先在全板设置中载入 FPC—RIS 映射", padding=8)
        self.board.pack(fill="both", expand=True, pady=(10, 0))
        from ris_manual_control import ManualControl
        self.manual = ManualControl(self, self.mapping_page, self.board)
        self.canvas = self.manual.canvas
        ttk.Label(self.control_frame, text="本页仅配置。单元测试、电平和字节按钮选择待下发内容，点击右上角总按钮后生效。", style="Muted.TLabel").pack(side="bottom", anchor="w", pady=(10, 0))

    def _build_mt(self):
        box = ttk.LabelFrame(self.mt_frame, text="MT 时域表 · 400 路统一控制", padding=18)
        box.pack(fill="x")
        row = ttk.Frame(box)
        row.pack(fill="x", pady=(0, 12))
        ttk.Label(row, text="完整周期频率", font=("sans", 12, "bold")).pack(side="left")
        ttk.Entry(row, textvariable=self.fast_value, width=14).pack(side="left", padx=12)
        for unit in ("Hz", "k", "M", "G"):
            ttk.Radiobutton(row, text=unit, value=unit, variable=self.fast_unit).pack(side="left", padx=5)
        ttk.Label(row, text="1 Hz～5 MHz", style="Muted.TLabel").pack(side="left", padx=15)
        from ris_mt_gui import MTControls
        self.mt_controls = MTControls(self, box)
        self.fast_preview = ttk.Label(box, textvariable=self.fast_notice, foreground="#315b80", wraplength=1200)
        self.fast_preview.pack(anchor="w", pady=(16, 0))
        ttk.Label(self.mt_frame, text="加载表、预览、修改频率和选择播放方式只更新配置。\n下发后先上传并校验整表，再由 FPGA 按原协议播放。", style="Muted.TLabel", justify="left").pack(anchor="w", pady=18)

    def _build_settings(self):
        navigation = ttk.Frame(self.settings_frame)
        navigation.pack(fill="x", pady=(0, 10))
        ttk.Label(navigation, text="设置选项").pack(side="left")
        selector = ttk.Combobox(navigation, textvariable=self.settings_view, values=("输出设置", "FPC—RIS 映射", "通信日志"), state="readonly", width=21)
        selector.pack(side="left", padx=10)
        selector.bind("<<ComboboxSelected>>", lambda _: self.show_settings(self.settings_view.get()))
        self.settings_content = ttk.Frame(self.settings_frame)
        self.settings_content.pack(fill="both", expand=True)
        self.settings_frames = {name: ttk.Frame(self.settings_content) for name in ("输出设置", "FPC—RIS 映射", "通信日志")}
        general = self.settings_frames["输出设置"]
        box = ttk.LabelFrame(general, text="全板输出设置", padding=20)
        box.pack(fill="x")
        for value, label in (("none", "仅查看 / 编辑设置"), ("enable", "使能输出 · OE=1"), ("disable", "禁能输出 · OE=0，高阻")):
            ttk.Radiobutton(box, text=label, variable=self.settings_mode, value=value).pack(anchor="w", pady=8)
        ttk.Label(box, text="输出设置经右上角“下发指令”应用。高阻与全板低电平是不同的输出状态。", style="Muted.TLabel").pack(anchor="w", pady=(12, 0))
        mapping = ttk.LabelFrame(general, text="FPC—RIS 接线映射", padding=20)
        mapping.pack(fill="x", pady=16)
        ttk.Label(mapping, text="管理接口绑定、空间映射、逐点标定和接线测试。", style="Muted.TLabel").pack(anchor="w")
        ttk.Button(mapping, text="打开 FPC—RIS 映射设置", command=self.open_mapping).pack(anchor="w", pady=(12, 0))
        self.mapping_frame = self.settings_frames["FPC—RIS 映射"]
        logs = self.settings_frames["通信日志"]
        ttk.Label(logs, textvariable=self.state, wraplength=1300).pack(anchor="w", pady=8)
        self.log = ScrolledText(logs, height=12, wrap="word", state="disabled", font=("monospace", 10))
        self.log.pack(fill="both", expand=True)
        self.settings_frames["输出设置"].pack(fill="both", expand=True)

    def show_settings(self, name):
        for frame in self.settings_frames.values():
            frame.pack_forget()
        self.settings_view.set(name)
        self.settings_frames[name].pack(fill="both", expand=True)
        self.refresh_pending()

    def show_page(self, page):
        page = {"control": "board", "mapping": "settings"}.get(page, page)
        if page not in self.frames:
            raise ValueError("未知配置页面")
        for frame in self.frames.values():
            frame.pack_forget()
        self.current_page = page
        self.frames[page].pack(fill="both", expand=True)
        self.feature.set(FEATURES.get(page, "请选择功能"))
        self.page_hint.set("选择一项功能，进入独立的配置页面。" if page == "home" else f"{FEATURES[page]} · 配置完成后，点击右上角“下发指令”")
        self.refresh_pending()
        if self.mapping_page:
            self.mapping_page.update_state()

    def open_mapping(self):
        self.show_settings("FPC—RIS 映射")
        self.show_page("settings")

    def toggle_chip_editor(self):
        if self.show_chip_editor.get():
            if self.board_mode.get() != "manual":
                self.last_board_mode = self.board_mode.get()
            self.board_modes.pack_forget()
            self.board_mode.set("manual")
            self.local_controls.pack(fill="both", expand=True)
        else:
            self.local_controls.pack_forget()
            self.board_modes.pack(fill="x", before=self.board_toggle)
            self.board_mode.set(self.last_board_mode)

    def mapping_shortcut(self, action):
        if self.current_page == "settings" and self.settings_view.get() == "FPC—RIS 映射":
            getattr(self.mapping_page, action)()
            return "break"
        if self.current_page == "patterns":
            getattr(self.pattern_page, "save_pattern" if action == "save" else action)()
            return "break"

    def mapping_updated(self):
        if self.manual:
            self.manual.refresh()
        if self.pattern_page:
            self.pattern_page.update_state()
        self.refresh_pending()

    def command(self, command, callback=None, owner=None, summary=None, mapping_document=None, feature=None):
        """Configuration API. Never writes or stops a running sequence."""
        if owner is not None:
            return False
        page = feature or self.current_page
        if page not in ("board", "settings"):
            self.notice.set("请先选择全板控制或全板设置页面。")
            return False
        action = OutputAction("command", command, summary or describe_command(command), callback, mapping_document)
        self.staged[page] = action
        if page == "board":
            self.byte_scope = None
            self.board_mode.set("manual")
        else:
            self.settings_mode.set("staged")
        self.notice.set(f"已配置：{action.summary}。点击右上角“下发指令”后生效。")
        self.refresh_pending()
        return True

    def stage_mt(self, loop=None):
        if loop is not None:
            self.mt_controls.loop.set(bool(loop))
        self.mt_action.set("play")
        self.refresh_pending()

    def stage_mt_stop(self):
        self.mt_action.set("stop")

    def start_fast(self):
        self.stage_mt()
        return True

    def start_blink(self):
        self.board_mode.set("blink")

    def _prepare_action(self):
        page = self.current_page
        if page == "board":
            mode = self.board_mode.get()
            commands = {"stop": "STOP", "all0": "ALL 0", "all1": "ALL 1"}
            if mode in commands:
                command = commands[mode]
            elif mode == "blink":
                try:
                    period = int(self.period.get())
                except ValueError:
                    raise ValueError("切换间隔需要在 100–60000 ms 之间。") from None
                if not 100 <= period <= 60000:
                    raise ValueError("切换间隔需要在 100–60000 ms 之间。")
                command = f"BLINK {period}"
            elif mode == "fast":
                plan = plan_frequency(self.board_frequency.get(), self.board_unit.get())
                command = f"FASTTICKS {plan.ticks}"
            else:
                if self.byte_scope is not None:
                    index = self.selected_index()
                    try:
                        value = int(self.hex_value.get().strip(), 16)
                        if not 0 <= value <= 255:
                            raise ValueError()
                    except ValueError:
                        raise ValueError("字节需要是 00–FF 的十六进制数。") from None
                    command = f"{'GROUP' if self.byte_scope else 'CHIP'} {index // 5 if self.byte_scope else index} {value:02X}"
                    return OutputAction("command", command, describe_command(command))
                action = self.staged.get("board")
                if action is None:
                    raise ValueError("请选择单元或芯片的待下发配置。")
                return self._validate_mapping(action)
            return OutputAction("command", command, describe_command(command))
        if page == "mt":
            if self.mt_action.get() == "stop":
                return OutputAction("command", "STOP", "停止 MT / 保持当前输出")
            if not self.mt_controls:
                raise ValueError("正在初始化 MT 配置。")
            if self.mt_controls.rows:
                plan = self.mt_controls.plan()
                return OutputAction("mt", plan, f"MT {'循环整表' if plan.loop else '播放一次'} · {len(plan.rows)} 周期 · {frequency_text(plan.actual)}")
            plan = plan_frequency(self.fast_value.get(), self.fast_unit.get())
            return OutputAction("command", f"FASTTICKS {plan.ticks}", f"默认方波 · {frequency_text(plan.actual)}")
        if page == "patterns":
            if not self.pattern_page:
                raise ValueError("正在初始化图案配置。")
            return self.pattern_page.prepare_action()
        if page == "settings":
            view, mode = self.settings_view.get(), self.settings_mode.get()
            if view == "通信日志":
                raise ValueError("通信日志仅供查看。")
            if view == "FPC—RIS 映射":
                action = self.staged.get("settings")
                if action is None:
                    raise ValueError("可选择接线测试内容，再通过总按钮下发。")
                return self._validate_mapping(action)
            if mode in ("enable", "disable"):
                command = "OE 1" if mode == "enable" else "OE 0"
                return OutputAction("command", command, describe_command(command))
            raise ValueError("选择输出设置，或进入 FPC—RIS 映射。")
        raise ValueError("选择功能并配置参数。")

    def _validate_mapping(self, action):
        if action.mapping_document is not None and action.mapping_document != self.mapping_page.model.document():
            raise ValueError("映射已修改，请重新选择单元或测试配置。")
        return action

    def refresh_pending(self):
        if not hasattr(self, "apply_button"):
            return
        try:
            action = self.pattern_page.preview_action() if self.current_page == "patterns" and self.pattern_page else self._prepare_action()
            text, available = "待下发：" + action.summary, True
        except ValueError as error:
            action, text, available = None, str(error), False
        self.pending_text.set(text)
        cancel = action and action.kind == "command" and action.payload == "STOP" and self.mt_uploading
        enabled = self.connected and available and (not self.busy or cancel)
        self.apply_button.configure(state="normal" if enabled else "disabled", text="取消上传并停止" if cancel else "下发指令")
        try:
            plan = plan_frequency(self.board_frequency.get(), self.board_unit.get())
            self.frequency_preview.set(f"方波预览：{frequency_text(plan.requested)} → 实际 {frequency_text(plan.actual)}；频率范围 1 Hz～5 MHz。")
        except ValueError as error:
            self.frequency_preview.set(str(error))
        self.preview_frequency()

    def preview_frequency(self):
        if not self.mt_controls or not hasattr(self, "fast_preview"):
            return
        try:
            if self.mt_controls.rows:
                plan = self.mt_controls.plan()
                text = f"MT：{len(plan.rows)} 个周期，{len(plan.segments)} 个硬件时段；实际 {frequency_text(plan.actual)}；{'循环整表' if plan.loop else '播放一次，结束后置低'}。"
            else:
                plan = plan_frequency(self.fast_value.get(), self.fast_unit.get())
                text = f"默认方波：M=50%，T=0%；实际 {frequency_text(plan.actual)}。"
            self.fast_notice.set(text + " 配置经总下发按钮应用。")
            self.fast_preview.configure(foreground="#315b80")
        except ValueError as error:
            self.fast_notice.set(str(error))
            self.fast_preview.configure(foreground="#a23a28")

    def _check_capability(self, action):
        if action.kind == "mt" and not self.latest.get("mt_supported"):
            raise ValueError("板端不支持 MT 表；请使用配套 MT 版 BIT 和 ELF。")
        if action.kind == "command" and action.payload.startswith("FASTTICKS") and not self.latest.get("fast_variable"):
            raise ValueError("板端不支持可编程方波；请使用配套 BIT 和 ELF。")

    def apply_current(self):
        """The sole user entry point that authorizes output-changing work."""
        if not self.connected or self.closed:
            self.notice.set("请先连接板卡。")
            return False
        try:
            action = self._prepare_action()
            self._check_capability(action)
        except ValueError as error:
            self.notice.set(str(error))
            return False
        if self.busy:
            if self.mt_uploading and action.kind == "command" and action.payload == "STOP":
                self.mt_cancel.set()
                self.notice.set("已通过总按钮取消上传；等待当前应答后下发 STOP。")
                return True
            self.notice.set("当前操作尚未确认，请稍后下发。")
            return False
        # Compile and validate before touching the previously applied run.
        self.pattern_page.stop("已应用其他配置，图案播放停止")
        if self.mapping_page.follow_timer:
            self.mapping_page.frame.after_cancel(self.mapping_page.follow_timer)
            self.mapping_page.follow_timer = None
        self.inflight_action = action
        self.notice.set(f"正在下发：{action.summary}；等待板端确认…")
        if action.kind == "playlist":
            self.playback_plan = action.payload
            self.pattern_page.begin_playback(action.payload)
            return True
        self.mt_cancel.clear()
        self.mt_uploading = action.kind == "mt"
        self._write_authorized = True
        try:
            return self.submit(action.kind, action.payload, action.callback)
        finally:
            self._write_authorized = False

    def send_play_frame(self, command, callback, owner):
        """Only frames in the playlist snapshot approved by the total button."""
        if not self.playback_plan or owner is not self.pattern_page.player or not owner.active:
            return False
        expected = "FRAME " + self.playback_plan.steps[owner.index].image.hex().upper()
        if command != expected:
            return False
        self._write_authorized = True
        try:
            return self.submit("command", command, callback)
        finally:
            self._write_authorized = False

    def selected_index(self):
        try:
            index = int(self.chip.get()) - 1
        except ValueError:
            raise ValueError("芯片编号需要在 1–50 之间") from None
        if not 0 <= index < 50:
            raise ValueError("芯片编号需要在 1–50 之间")
        return index

    def bits_to_hex(self):
        self.hex_value.set(f"{sum(v.get() << i for i, v in enumerate(self.bits)):02X}")

    def hex_to_bits(self, quiet=False):
        try:
            value = int(self.hex_value.get().strip(), 16)
            if not 0 <= value <= 255:
                raise ValueError()
        except ValueError:
            if not quiet:
                self.notice.set("字节需要是 00–FF 的十六进制数。")
            return False
        for index, bit in enumerate(self.bits):
            bit.set((value >> index) & 1)
        self.hex_value.set(f"{value:02X}")
        return True

    def select_chip(self, redraw=True):
        try:
            index = self.selected_index()
        except ValueError as error:
            self.notice.set(str(error))
            return
        self.selected.set(f"第 {index + 1} 片 · 实物 U{index + 4} · 第 {index // 5 + 1} 组")
        if self.latest:
            self.hex_value.set(f"{bytes.fromhex(self.latest['image'])[index]:02X}")
            self.hex_to_bits()
        if redraw:
            self.draw()

    def apply_byte(self, group):
        try:
            index = self.selected_index()
        except ValueError as error:
            self.notice.set(str(error))
            return False
        if self.hex_to_bits():
            result = self.command(f"{'GROUP' if group else 'CHIP'} {index // 5 if group else index} {self.hex_value.get()}")
            self.byte_scope = bool(group)
            self.refresh_pending()
            return result
        return False

    def draw(self):
        if self.manual:
            self.manual.refresh()

    def _enable(self):
        self.connect_button.configure(state="disabled" if self.connected or self.busy else "normal")
        self.disconnect_button.configure(state="normal" if self.connected and not self.busy else "disabled")
        for entry in (self.host_entry, self.port_entry):
            entry.configure(state="disabled" if self.connected or self.busy else "normal")
        if self.mt_controls:
            self.mt_controls.update_state()
        if self.mapping_page and self.mapping_page.alive:
            self.mapping_page.update_state()
        if self.pattern_page:
            self.pattern_page.update_state()
        self.refresh_pending()
        self.refresh_status()

    def refresh_status(self):
        player = self.pattern_page.player if self.pattern_page else None
        title, detail, color = confirmed_status(self.connected, self.latest, self.applied_action, player)
        if self.mt_uploading:
            title, detail, color = "MT 表上传中", "等待整表校验；完成后启动播放", "#fbbf24"
        self.status_title.set(title)
        self.status_detail.set(detail)
        self.monitor_title.configure(foreground=color)
        if self.connected and self.latest:
            reply = self.latest
            self.status_meta.set(f"板端确认 · 帧数 {reply['frames']} · {self.confirmed_time}")
            self.state.set(f"{title} | {detail} | 状态 0x{reply['status']:08X} | 错误 0x{reply['errors']:08X}")
        else:
            self.status_meta.set("未连接 · 保留最后镜像仅作参考")
            self.state.set("未连接 · 工作状态未确认")

    def append_log(self, text):
        self.log.configure(state="normal")
        self.log.insert("end", f"{time.strftime('%H:%M:%S')}  {text}\n")
        self.log.see("end")
        self.log.configure(state="disabled")

    def submit(self, kind, payload=None, callback=None):
        if kind in ("command", "mt") and not self._write_authorized:
            self.notice.set("输出指令必须通过右上角“下发指令”应用。")
            return False
        if self.busy or self.closed:
            return False
        self.pending_callback, self.busy = callback, True
        self._enable()
        self.tasks.put((kind, payload))
        return True

    def connect(self):
        try:
            host, port = self.host.get().strip(), int(self.port.get())
            if not host or not 1 <= port <= 65535:
                raise ValueError()
        except ValueError:
            self.notice.set("请输入有效 IP 地址和端口。")
            return False
        self.notice.set(f"正在连接 {host}:{port}…")
        return self.submit("connect", (host, port))

    def disconnect(self):
        if self.busy:
            return False
        self.pattern_page.stop("连接断开，图案播放停止")
        return self.submit("disconnect")

    def _worker(self):
        client = None
        while True:
            kind, payload = self.tasks.get()
            if kind == "quit":
                if client:
                    client.close()
                return
            try:
                if kind == "connect":
                    if client:
                        client.close()
                    client = RisClient(*payload)
                    reply = client.command("STATUS")
                elif kind == "disconnect":
                    if client:
                        client.close()
                    client, reply = None, None
                elif kind == "mt":
                    if client is None:
                        raise ConnectionError("尚未连接板卡")
                    reply = None
                    cancelled = False
                    for index, command in enumerate(payload.commands()):
                        if self.mt_cancel.is_set():
                            if not self.closed:
                                reply = client.command("STOP")  # Total-button cancellation.
                                cancelled = True
                            break
                        reply = client.command(command)
                        if not reply["ok"] or reply["errors"]:
                            raise RuntimeError(f"MT 上传/启动被拒绝：{command.split()[0]}，rc={reply['rc']}")
                        if command.startswith("MTSEG") and reply.get("mt_loaded") != index:
                            raise RuntimeError("MT 上传确认计数不一致")
                        if index % 32 == 0:
                            self.results.put(("mt_progress", min(index, len(payload.segments)), None, None))
                    if cancelled:
                        kind = "mt_cancelled"
                else:
                    if client is None:
                        raise ConnectionError("尚未连接板卡")
                    reply = client.command(payload if kind == "command" else "STATUS")
                self.results.put((kind, payload, reply, None))
            except Exception as error:
                if client:
                    client.close()
                client = None
                self.results.put((kind, payload, None, str(error)))

    def _receive(self):
        if self.closed:
            return
        try:
            while True:
                kind, payload, reply, error = self.results.get_nowait()
                if kind == "mt_progress":
                    self.notice.set(f"MT 表上传中：已确认 {payload} 个时段")
                    continue
                callback, self.pending_callback = self.pending_callback, None
                self.busy = False
                if kind in ("mt", "mt_cancelled"):
                    self.mt_uploading = False
                # A cancellation may arrive after MTSTART was sent or its result
                # was queued. Honor that explicit total-button click with STOP.
                if kind == "mt" and self.mt_cancel.is_set() and not error and reply:
                    self.connected, self.latest = True, reply
                    self.confirmed_time = time.strftime("%H:%M:%S")
                    self.applied_action = None
                    self.inflight_action = OutputAction("command", "STOP", "取消 MT 上传并停止")
                    self.notice.set("正在完成取消请求，等待 STOP 确认…")
                    self._write_authorized = True
                    try:
                        self.submit("command", "STOP")
                    finally:
                        self._write_authorized = False
                    continue
                if error or reply is None:
                    self.connected = False
                    self.applied_action = self.inflight_action = None
                    self.pattern_page.stop("连接断开，图案播放停止")
                    self.notice.set(f"连接中断：{error}。命令结果未确认，请重连查询。" if error else "已断开连接。工作状态请重连后确认。")
                    self.append_log(self.notice.get())
                else:
                    self.connected, self.latest = True, reply
                    self.confirmed_time = time.strftime("%H:%M:%S")
                    if not reply["ok"] or reply["errors"]:
                        self.applied_action = None
                        self.notice.set(f"板端拒绝或执行出错：rc={reply['rc']}，错误 0x{reply['errors']:08X}。")
                        if kind != "poll":
                            self.append_log(self.notice.get())
                    elif kind == "connect":
                        self.applied_action = None
                        self.notice.set(f"已连接 {self.host.get()}:{self.port.get()}；状态来自板端确认。")
                        self.append_log(self.notice.get())
                    elif kind in ("command", "mt", "mt_cancelled"):
                        self.applied_action = self.inflight_action
                        if kind == "mt_cancelled":
                            self.applied_action = OutputAction("command", "STOP", "取消 MT 上传并停止")
                        self.notice.set("已确认：" + (self.applied_action.summary if self.applied_action else describe_command(payload)))
                        self.append_log(self.notice.get())
                self._enable()
                self.draw()
                if callback:
                    callback(reply, error)
                self.refresh_status()
        except queue.Empty:
            pass
        self.receive_timer = self.root.after(50, self._receive)

    def _poll(self):
        if self.closed:
            return
        if self.connected and not self.busy:
            self.submit("poll")
        self.poll_timer = self.root.after(1000, self._poll)

    def close(self):
        if self.pattern_page and not self.pattern_page.may_discard():
            return
        if self.mapping_page and self.mapping_page.alive and not self.mapping_page.close():
            return
        self.pattern_page.shutdown()
        self.closed = True
        self.mt_cancel.set()
        self.root.after_cancel(self.receive_timer)
        self.root.after_cancel(self.poll_timer)
        self.tasks.put(("quit", None))
        self.root.destroy()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--connect", action="store_true", help="连接并读取状态；不应用输出配置")
    views = parser.add_mutually_exclusive_group()
    views.add_argument("--mapping", action="store_true", help="打开全板设置中的 FPC—RIS 映射")
    views.add_argument("--patterns", action="store_true", help="打开图案切换配置")
    views.add_argument("--mt", action="store_true", help="打开 MT 时域配置")
    parser.add_argument("--mapping-file", help="导入映射；副本的保存目标位于新目录")
    args = parser.parse_args()
    root = tk.Tk()
    app = RisGui(root, args.host, args.port)
    saved = Path(args.mapping_file) if args.mapping_file else Path(__file__).resolve().parent / "mappings" / "ris_mapping.json"
    if saved.exists():
        app.mapping_page.load_path(saved)
    if args.mapping:
        app.open_mapping()
    elif args.patterns:
        app.show_page("patterns")
    elif args.mt:
        app.show_page("mt")
    if args.connect:
        root.after(200, app.connect)
    root.mainloop()


if __name__ == "__main__":
    main()
