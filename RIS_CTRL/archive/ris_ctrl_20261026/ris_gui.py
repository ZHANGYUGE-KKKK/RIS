#!/usr/bin/env python3
"""Tkinter controller for the RIS706 lwIP TCP firmware; Python standard library."""
import argparse
import queue
import threading
import time
import tkinter as tk
from tkinter import ttk
from tkinter.scrolledtext import ScrolledText

from ris_client import DEFAULT_HOST, DEFAULT_PORT, RisClient
from ris_frequency import active_frequency, frequency_text, plan_frequency


class RisGui:
    def __init__(self, root, host=DEFAULT_HOST, port=DEFAULT_PORT, pattern_storage=None):
        self.root = root
        self.connected = False
        self.busy = False
        self.closed = False
        self.latest = None
        self.tasks = queue.Queue()
        self.results = queue.Queue()
        self.pending_callback = None
        self.mapping_page = None
        self.manual = None
        self.pattern_page = None
        self.pattern_storage = pattern_storage
        self.controls = []
        self.fast_buttons = []
        self.host = tk.StringVar(value=host)
        self.port = tk.StringVar(value=str(port))
        self.chip = tk.StringVar(value="1")
        self.hex_value = tk.StringVar(value="00")
        self.period = tk.StringVar(value="1000")
        self.notice = tk.StringVar(value="未连接。电脑有线网卡：192.168.1.20/24；板卡：192.168.1.11")
        self.state = tk.StringVar(value="等待连接")
        self.selected = tk.StringVar(value="第 1 片 · 实物 U4 · 第 1 组")
        self.bits = [tk.IntVar(value=0) for _ in range(8)]
        self._build()
        threading.Thread(target=self._worker, daemon=True).start()
        self.receive_timer = self.root.after(50, self._receive)
        self.poll_timer = self.root.after(1000, self._poll)
        self.root.protocol("WM_DELETE_WINDOW", self.close)

    def _build(self):
        root = self.root
        root.title("RIS 400 路控制台 · ZC706")
        width = min(1420, root.winfo_screenwidth() - 60)
        height = min(1000, root.winfo_screenheight() - 80)
        root.geometry(f"{width}x{height}+{max(0, (root.winfo_screenwidth() - width) // 2)}+10")
        root.minsize(min(1180, width), min(810, height))
        style = ttk.Style(root)
        style.theme_use("clam")
        style.configure("TButton", padding=(10, 5))
        style.configure("Title.TLabel", font=("sans", 19, "bold"))
        style.configure("Status.TLabel", font=("sans", 11))
        style.configure("TNotebook.Tab", padding=(18, 7))
        style.configure("Main.TNotebook.Tab", padding=(12, 4), font=("sans", 10))
        style.map("Main.TNotebook.Tab",
                  padding=[("selected", (22, 10)), ("!selected", (12, 4))],
                  font=[("selected", ("sans", 11, "bold")), ("!selected", ("sans", 10))],
                  background=[("selected", "#f6f8fb"), ("!selected", "#d8dde3")],
                  foreground=[("selected", "#174e75"), ("!selected", "#526075")],
                  expand=[("selected", (2, 4, 2, 0)), ("!selected", (0, 0, 0, 0))])
        self.view = tk.StringVar(value="control")
        menu = tk.Menu(root)
        self.view_menu = tk.Menu(menu, tearoff=False)
        for label, value in (("控制面板", "control"), ("FPC—RIS 映射", "mapping"), ("图案与切换", "patterns")):
            self.view_menu.add_radiobutton(label=label, variable=self.view, value=value,
                                          command=lambda page=value: self.show_page(page))
        menu.add_cascade(label="界面", menu=self.view_menu)
        root.configure(menu=menu)
        root.bind("<Control-s>", lambda _: self.mapping_shortcut("save"))
        root.bind("<Control-z>", lambda _: self.mapping_shortcut("undo"))
        main = ttk.Frame(root, padding=12)
        main.pack(fill="both", expand=True)
        ttk.Label(main, text="RIS 400 路控制台", style="Title.TLabel").pack(anchor="w")
        ttk.Label(main, text="ZC706 · 50 × 74LVC8T595 · 静态电平测量与图案切换").pack(anchor="w", pady=(2, 5))
        connection = ttk.Frame(main)
        connection.pack(fill="x")
        ttk.Label(connection, text="板卡 IP").pack(side="left")
        self.host_entry = ttk.Entry(connection, textvariable=self.host, width=18)
        self.host_entry.pack(side="left", padx=(8, 16))
        ttk.Label(connection, text="TCP 端口").pack(side="left")
        self.port_entry = ttk.Entry(connection, textvariable=self.port, width=7)
        self.port_entry.pack(side="left", padx=8)
        self.connect_button = ttk.Button(connection, text="连接板卡", command=self.connect)
        self.connect_button.pack(side="left", padx=8)
        self.disconnect_button = ttk.Button(connection, text="断开连接", command=self.disconnect, state="disabled")
        self.disconnect_button.pack(side="left")
        ttk.Label(main, textvariable=self.notice, foreground="#315b80", wraplength=1110).pack(anchor="w", pady=(5, 6))

        self.pages = ttk.Notebook(main, style="Main.TNotebook")
        self.pages.pack(fill="both", expand=True)
        self.control_frame = ttk.Frame(self.pages, padding=(0, 10, 0, 0))
        self.mapping_frame = ttk.Frame(self.pages)
        self.pattern_frame = ttk.Frame(self.pages)
        self.pages.add(self.control_frame, text="控制面板")
        self.pages.add(self.mapping_frame, text="FPC—RIS 映射")
        self.pages.add(self.pattern_frame, text="图案与切换")
        self.pages.bind("<<NotebookTabChanged>>", self._page_changed)
        from ris_mapping_gui import MappingPage
        self.mapping_page = MappingPage(self, self.mapping_frame)
        self._build_control(self.control_frame)
        from ris_pattern_gui import PatternPage
        self.pattern_page = PatternPage(self, self.mapping_page, self.pattern_frame, self.pattern_storage)
        self._build_fast_controls()
        self._enable()

    def _build_fast_controls(self):
        box = ttk.LabelFrame(self.control_frame, text="全0 / 全1 · FPGA 高速方波", padding=6)
        box.pack(fill="x", before=self.control_frame.winfo_children()[1], pady=(5, 0))
        row = ttk.Frame(box)
        row.pack(fill="x")
        self.fast_notice = tk.StringVar()
        self.fast_value = tk.StringVar(value="5")
        self.fast_unit = tk.StringVar(value="M")
        ttk.Label(row, text="完整周期频率：").pack(side="left")
        self.fast_entry = ttk.Entry(row, textvariable=self.fast_value, width=14)
        self.fast_entry.pack(side="left", padx=4)
        self.fast_entry.bind("<Return>", lambda _: self.start_fast())
        for unit in ("Hz", "k", "M", "G"):
            button = ttk.Radiobutton(row, text=unit, value=unit, variable=self.fast_unit,
                                     style="Toolbutton", width=3)
            button.pack(side="left", padx=4)
            self.fast_buttons.append(button)
        self.fast_start = ttk.Button(row, text="启动 / 应用频率", command=self.start_fast)
        self.fast_start.pack(side="left", padx=8)
        self.fast_buttons.append(self.fast_start)
        self._button(row, "停止方波 / 保持", lambda: self.command("STOP")).pack(side="left", padx=8)
        ttk.Label(row, text="1 Hz～5 MHz · 50%占空比").pack(side="left", padx=6)
        self.fast_preview = ttk.Label(box, textvariable=self.fast_notice, foreground="#315b80")
        self.fast_preview.pack(anchor="w", pady=(4, 0))
        for variable in (self.fast_value, self.fast_unit):
            variable.trace_add("write", lambda *_: self.preview_frequency())

    def preview_frequency(self):
        try:
            plan = plan_frequency(self.fast_value.get(), self.fast_unit.get())
        except ValueError as error:
            self.fast_notice.set(str(error))
            self.fast_preview.configure(foreground="#a23a28")
            return
        error = (plan.actual / plan.requested - 1) * 100
        self.fast_notice.set(f"设定 {frequency_text(plan.requested)} → 可生成 {frequency_text(plan.actual)}"
                             f"（偏差 {error:+.4f}%）；半周期 {plan.ticks / .3:.6g} ns。单位按钮只编辑，点击应用后生效。")
        self.fast_preview.configure(foreground="#315b80")

    def start_fast(self):
        try:
            plan = plan_frequency(self.fast_value.get(), self.fast_unit.get())
        except ValueError as error:
            self.notice.set(str(error))
            return False
        if not self.connected or not self.latest or not self.latest.get("fast_variable", False):
            self.notice.set("请连接支持可编程方波的板端程序；需要下载配套FPGA和ELF。")
            return False
        return self.command(f"FASTTICKS {plan.ticks}")

    def _build_control(self, main):
        actions = ttk.LabelFrame(main, text="全板操作", padding=6)
        actions.pack(fill="x")
        for label, command in (("400 路全低 · 0", "ALL 0"), ("400 路全高 · 1", "ALL 1"),
                               ("停止切换并保持", "STOP"), ("使能输出", "OE 1"), ("禁能输出 · 高阻", "OE 0")):
            self._button(actions, label, lambda cmd=command: self.command(cmd)).pack(side="left", padx=4)
        ttk.Label(actions, text="每次切换间隔 ms").pack(side="left", padx=(12, 4))
        interval = ttk.Spinbox(actions, from_=100, to=60000, increment=100, textvariable=self.period, width=7)
        interval.pack(side="left")
        self.controls.append(interval)
        self._button(actions, "启动切换", self.start_blink).pack(side="left", padx=6)
        ttk.Label(main, textvariable=self.state, style="Status.TLabel").pack(anchor="w", pady=5)

        advanced = ttk.Frame(main)
        advanced.pack(fill="x", pady=(0, 5))
        self.show_chip_editor = tk.BooleanVar(value=False)
        ttk.Checkbutton(advanced, text="展开芯片 / 5片组字节控制", variable=self.show_chip_editor,
                        command=self.toggle_chip_editor).pack(side="left")
        ttk.Label(advanced, text="阵列与映射页共用接线表；选择单元后，可在右侧手动控制。").pack(side="left", padx=15)
        self.show_log = tk.BooleanVar(value=False)
        ttk.Checkbutton(advanced, text="通信日志", variable=self.show_log,
                        command=self.toggle_log).pack(side="right")
        for text, command in (("编辑映射", self.open_mapping), ("恢复草稿", self.mapping_page.recover),
                              ("打开映射", self.mapping_page.load)):
            ttk.Button(advanced, text=text, style="Mapping.TButton", command=command).pack(side="right", padx=3)
        self.editor = editor = ttk.LabelFrame(main, text="单片 / 5 片组：修改后点击写入，其余芯片保持", padding=10)
        ttk.Label(editor, text="芯片编号 1–50").grid(row=0, column=0, sticky="w")
        selector = ttk.Spinbox(editor, from_=1, to=50, textvariable=self.chip, width=5, command=self.select_chip)
        selector.grid(row=0, column=1, padx=8)
        selector.bind("<Return>", lambda _: self.select_chip())
        selector.bind("<FocusOut>", lambda _: self.select_chip())
        self.controls.append(selector)
        ttk.Label(editor, textvariable=self.selected).grid(row=0, column=2, columnspan=4, sticky="w", padx=12)
        ttk.Label(editor, text="待写入 HEX").grid(row=0, column=6, padx=(15, 4))
        entry = ttk.Entry(editor, textvariable=self.hex_value, width=7)
        entry.grid(row=0, column=7)
        entry.bind("<Return>", lambda _: self.hex_to_bits())
        entry.bind("<FocusOut>", lambda _: self.hex_to_bits(quiet=True))
        self.controls.append(entry)
        for bit in range(8):
            check = ttk.Checkbutton(editor, text=f"Q{bit}", variable=self.bits[bit], command=self.bits_to_hex)
            check.grid(row=1, column=bit, padx=7, pady=10)
            self.controls.append(check)
        self._button(editor, "写入所选片", lambda: self.apply_byte(False)).grid(row=0, column=8, padx=12)
        self._button(editor, "写入所选 5 片组", lambda: self.apply_byte(True)).grid(row=1, column=8, padx=12)
        ttk.Label(editor, text="Q0 对应字节 bit0；FF = 8 路全高，00 = 8 路全低。").grid(row=2, column=0, columnspan=9, sticky="w")

        self.board = board = ttk.LabelFrame(main, text="RIS 阵列 · 点击选择单元，右侧手动检查接线", padding=8)
        from ris_manual_control import ManualControl
        self.manual = ManualControl(self, self.mapping_page, board)
        self.canvas = self.manual.canvas
        footer = ttk.Frame(main)
        footer.pack(side="bottom", fill="x")
        ttk.Label(footer, textvariable=self.mapping_page.notice, foreground="#245c85", wraplength=1120).pack(anchor="w")
        ttk.Label(footer, text="绿色：已确认的置高命令；格内数字：CH1–40。界面不检测实际电压。黑表笔接 GND，红表笔接所选单元。").pack(anchor="w", pady=(4, 6))
        self.log = ScrolledText(footer, height=3, wrap="word", state="disabled", font=("monospace", 9))
        board.pack(fill="both", expand=True, pady=(12, 8))

    def toggle_chip_editor(self):
        if self.show_chip_editor.get():
            self.editor.pack(fill="x", before=self.board)
        else:
            self.editor.pack_forget()

    def toggle_log(self):
        if self.show_log.get():
            self.log.pack(fill="x")
        else:
            self.log.pack_forget()

    def mapping_updated(self):
        if self.manual:
            self.manual.refresh()
        if self.pattern_page:
            self.pattern_page.update_state()

    def _button(self, parent, text, callback):
        button = ttk.Button(parent, text=text, command=callback)
        self.controls.append(button)
        return button

    def _enable(self):
        for control in self.controls:
            enabled = self.connected and (not self.busy or not isinstance(control, ttk.Button))
            control.configure(state="normal" if enabled else "disabled")
        self.connect_button.configure(state="disabled" if self.connected or self.busy else "normal")
        self.disconnect_button.configure(state="normal" if self.connected and not self.busy else "disabled")
        for entry in (self.host_entry, self.port_entry):
            entry.configure(state="disabled" if self.connected or self.busy else "normal")
        supported = self.connected and self.latest and self.latest.get("fast_variable", False)
        for button in self.fast_buttons:
            enabled = button is not self.fast_start or (supported and not self.busy)
            button.configure(state="normal" if enabled else "disabled")
        if hasattr(self, "fast_notice"):
            self.preview_frequency()
        if self.mapping_page and self.mapping_page.alive:
            self.mapping_page.update_state()

    def open_mapping(self):
        self.show_page("mapping")

    def show_page(self, page):
        self.pages.select({"control": self.control_frame, "mapping": self.mapping_frame, "patterns": self.pattern_frame}[page])
        self._page_changed()

    def _page_changed(self, _event=None):
        selected = self.pages.select()
        self.view.set("mapping" if selected == str(self.mapping_frame) else
                      ("patterns" if selected == str(self.pattern_frame) else "control"))
        if self.mapping_page:
            self.mapping_page.update_state()

    def mapping_shortcut(self, action):
        if self.view.get() == "mapping" and self.mapping_page:
            getattr(self.mapping_page, action)()
            return "break"
        if self.view.get() == "patterns" and self.pattern_page:
            getattr(self.pattern_page, "save_pattern" if action == "save" else action)()
            return "break"

    def append_log(self, text):
        self.log.configure(state="normal")
        self.log.insert("end", f"{time.strftime('%H:%M:%S')}  {text}\n")
        self.log.see("end")
        self.log.configure(state="disabled")

    def submit(self, kind, payload=None, callback=None):
        if self.busy or self.closed:
            return False
        self.pending_callback = callback
        self.busy = True
        self._enable()
        self.tasks.put((kind, payload))
        return True

    def connect(self):
        try:
            host = self.host.get().strip()
            port = int(self.port.get())
            if not host or not 1 <= port <= 65535:
                raise ValueError()
        except ValueError:
            self.notice.set("请输入有效 IP 地址和端口。")
            return
        self.notice.set(f"正在连接 {host}:{port}…")
        self.submit("connect", (host, port))

    def disconnect(self):
        if self.pattern_page:
            self.pattern_page.stop("已断开连接，图案播放停止")
        self.submit("disconnect")

    def command(self, command, callback=None, owner=None):
        if self.mapping_page and self.mapping_page.follow_timer:
            self.mapping_page.frame.after_cancel(self.mapping_page.follow_timer)
            self.mapping_page.follow_timer = None
        if self.pattern_page and owner is not self.pattern_page.player:
            self.pattern_page.stop("其他控制操作已接管，图案播放停止")
        if self.connected:
            return self.submit("command", command, callback=callback)
        return False

    def start_blink(self):
        try:
            period = int(self.period.get())
            if not 100 <= period <= 60000:
                raise ValueError()
        except ValueError:
            self.notice.set("切换间隔需要在 100–60000 ms 之间。")
            return
        self.command(f"BLINK {period}")

    def selected_index(self):
        index = int(self.chip.get()) - 1
        if not 0 <= index < 50:
            raise ValueError("芯片编号需要在 1–50 之间")
        return index

    def bits_to_hex(self):
        self.hex_value.set(f"{sum(v.get() << i for i, v in enumerate(self.bits)):02X}")

    def hex_to_bits(self, quiet=False):
        try:
            text = self.hex_value.get().strip()
            value = int(text, 16)
            if not 0 <= value <= 255:
                raise ValueError()
        except ValueError:
            if not quiet:
                self.notice.set("字节需要是 00–FF 的十六进制数。")
            return False
        for i, bit in enumerate(self.bits):
            bit.set((value >> i) & 1)
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
            image = bytes.fromhex(self.latest["image"])
            self.hex_value.set(f"{image[index]:02X}")
            self.hex_to_bits()
        if redraw:
            self.draw()

    def apply_byte(self, group):
        try:
            index = self.selected_index()
        except ValueError as error:
            self.notice.set(str(error))
            return
        if self.hex_to_bits():
            self.command(f"{'GROUP' if group else 'CHIP'} {index // 5 if group else index} {self.hex_value.get()}")

    def draw(self):
        if self.manual:
            self.manual.refresh()

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
                    client = None
                    reply = None
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
                callback = self.pending_callback
                self.pending_callback = None
                self.busy = False
                if error:
                    self.connected = False
                    self.notice.set(f"连接中断：{error}。命令结果可能未确认，请重连查询状态。")
                    self.state.set("未连接 · 保留最后一次图案作为参考")
                    self.append_log(self.notice.get())
                elif reply is None:
                    self.connected = False
                    self.notice.set("已断开。板卡停止定时切换并保持当前图案。")
                    self.state.set("未连接 · 保留最后一次图案作为参考")
                    self.append_log("断开连接")
                else:
                    self.connected = True
                    self.latest = reply
                    mode = f"定时切换：{reply['blink_ms']} ms" if reply["blink_ms"] else "静态保持"
                    if active_frequency(reply):
                        mode = f"硬件方波：实际 {frequency_text(active_frequency(reply))} · 全0/全1 · 50%占空比"
                    oe = "输出使能" if reply["oe"] else "输出禁能 / 高阻"
                    self.state.set(f"{mode}  |  {oe}  |  完成帧数 {reply['frames']}  |  状态 0x{reply['status']:08X}  |  错误 0x{reply['errors']:08X}")
                    if active_frequency(reply):
                        self.state.set(self.state.get() + f"  |  高速翻转计数 {reply.get('fast_edges', 0)}")
                    if not reply["ok"]:
                        self.notice.set(f"板端拒绝或执行出错：rc={reply['rc']}，错误标志 0x{reply['errors']:08X}。")
                        if kind != "poll":
                            self.append_log(self.notice.get())
                    elif kind == "connect":
                        self.notice.set(f"已连接 {self.host.get()}:{self.port.get()} · {reply['slots']} 帧缓存 · 图案由板端确认")
                        self.append_log(self.notice.get())
                        self.select_chip()
                    elif kind == "command":
                        self.notice.set(f"已完成：{payload}；帧数 {reply['frames']}。")
                        self.append_log(self.notice.get())
                self._enable()
                self.draw()
                if callback:
                    callback(reply, error)
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
        if self.pattern_page:
            self.pattern_page.stop("正在关闭，图案播放停止")
            if not self.pattern_page.may_discard():
                return
        if self.mapping_page and self.mapping_page.alive and not self.mapping_page.close():
            return
        if self.pattern_page:
            self.pattern_page.shutdown()
        self.closed = True
        self.root.after_cancel(self.receive_timer)
        self.root.after_cancel(self.poll_timer)
        self.tasks.put(("quit", None))
        self.root.destroy()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--connect", action="store_true", help="启动后连接板卡并读取状态")
    views = parser.add_mutually_exclusive_group()
    views.add_argument("--mapping", action="store_true", help="启动时选择 FPC—RIS 映射页（同一窗口）")
    views.add_argument("--patterns", action="store_true", help="启动时选择图案与切换页")
    parser.add_argument("--mapping-file", help="启动时载入指定FPC映射JSON，不下发图案")
    args = parser.parse_args()
    root = tk.Tk()
    app = RisGui(root, args.host, args.port)
    if args.mapping_file and not app.mapping_page.load_path(args.mapping_file):
        app.notice.set(app.mapping_page.notice.get())
    if args.mapping:
        root.after(100, app.open_mapping)
    elif args.patterns:
        root.after(100, lambda: app.show_page("patterns"))
    if args.connect:
        root.after(200, app.connect)
    root.mainloop()


if __name__ == "__main__":
    main()
