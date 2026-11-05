"""Visual FPC/RIS mapping editor, sharing the main GUI's single TCP connection."""
from ris_frequency import active_frequency, frequency_text
from pathlib import Path
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

from ris_mapping import PORTS, RisMapping, cell_port, fpc_probe_command, pin_trace, port_label, probe_command, source

from ris_topology import TopologyView


def record_status(value):
    if not value:
        return "未映射"
    return "实测确认" if value["verified"] else ("接线表·未实测" if value["basis"] == "wiring" else "手动·待核对")


class MappingPage:
    def __init__(self, app, parent, storage_dir=None):
        self.app = app
        self.alive = True
        self.model = RisMapping()
        self.history = []
        self.path = None
        self.dirty = False
        self.cell = None
        self.previous_cell = None
        self.probed = None
        self.follow_timer = None
        self.recovery_error = ""
        self.storage_dir = Path(storage_dir) if storage_dir else Path(__file__).resolve().parent / "mappings"
        self.recovery_path = self.storage_dir / "session_recovery.json"
        self.frame = ttk.Frame(parent)
        self.frame.pack(fill="both", expand=True)
        self.fpc = tk.StringVar(value="1")
        self.channel = tk.StringVar(value="1")
        self.port = tk.StringVar(value="")
        self.record_mode = tk.BooleanVar(value=False)
        self.measured = tk.BooleanVar(value=False)
        self.auto_next = tk.BooleanVar(value=True)
        self.auto_test = tk.BooleanVar(value=False)
        self.emphasize_connections = tk.BooleanVar(value=False)
        self.progress = tk.StringVar()
        self.connection = tk.StringVar()
        self.output_state = tk.StringVar(value="板端输出：尚未确认")
        self.description = tk.StringVar()
        self.selected_cell = tk.StringVar(value="尚未选择 RIS 单元")
        self.notice = tk.StringVar(value="绑定接口后按已确认的安装方向生成40路映射；点击单元查看595脚号，实测状态单独记录。")
        self.hover = tk.StringVar(value="视角：拓扑图 BIAS 一侧为上端；行从上到下、列从左到右。")
        self._build()
        self.refresh()

    def _build(self):
        ttk.Style(self.frame).configure("Mapping.TButton", padding=(6, 3))
        def button(parent, **options):
            return ttk.Button(parent, style="Mapping.TButton", **options)
        main = ttk.Frame(self.frame, padding=(0, 10, 0, 0))
        main.pack(fill="both", expand=True)
        top = ttk.Frame(main)
        top.pack(fill="x")
        ttk.Label(top, text="控制板 FPC → RIS 单元映射", font=("sans", 16, "bold")).pack(side="left")
        for text, callback in (("新建", self.new), ("打开 JSON", self.load), ("保存 JSON", self.save),
                               ("导出 CSV", self.export_csv), ("恢复草稿", self.recover), ("撤销", self.undo)):
            button(top, text=text, command=callback).pack(side="left", padx=3)
        progress = ttk.Frame(main)
        progress.pack(fill="x", pady=(6, 2))
        ttk.Label(progress, textvariable=self.progress).pack(side="left")
        ttk.Checkbutton(progress, text="加深其他连线", variable=self.emphasize_connections,
                        command=self.draw).pack(side="right")
        net = ttk.Frame(main)
        net.pack(fill="x")
        ttk.Label(net, textvariable=self.connection).pack(side="left")
        self.zero_button = button(net, text="选择结束测试 / 全板置低", command=self.all_low)
        self.zero_button.pack(side="right", padx=3)
        ttk.Label(main, textvariable=self.output_state, foreground="#315c74").pack(anchor="w", pady=(3, 0))

        footer = ttk.Frame(main)
        footer.pack(side="bottom", fill="x", pady=(6, 0))
        ttk.Label(footer, textvariable=self.hover, foreground="#526075", wraplength=1360).pack(anchor="w")
        ttk.Label(footer, textvariable=self.notice, foreground="#245c85", wraplength=1360).pack(anchor="w", pady=(4, 0))
        ttk.Label(footer, text="灰：未映射  淡紫：接线表  黄：手动待核对  浅蓝：已实测  绿：命令置高。颜色不代表实测电压；切换页面或退出不清零。").pack(anchor="w", pady=(3, 0))

        panes = ttk.Panedwindow(main, orient="horizontal")
        panes.pack(fill="both", expand=True, pady=(8, 0))
        visual = ttk.Frame(panes)
        panes.add(visual, weight=4)
        self.canvas = tk.Canvas(visual, background="#f6f8fb", highlightthickness=0)
        visual_scroll = ttk.Scrollbar(visual, orient="vertical", command=self.canvas.yview)
        visual_scroll.pack(side="right", fill="y")
        self.canvas.configure(yscrollcommand=visual_scroll.set)
        self.canvas.pack(fill="both", expand=True)
        self.topology = TopologyView(self, self.canvas)
        self.canvas.bind("<Configure>", lambda _: self.draw())
        self.canvas.bind("<Button-1>", self.click)
        self.canvas.bind("<Motion>", self.motion)

        side = ttk.Frame(panes, padding=(10, 0, 0, 0), width=330)
        panes.add(side, weight=0)
        tabs = ttk.Notebook(side, width=320)
        tabs.pack(fill="both", expand=True)
        calibration = ttk.Frame(tabs)
        records = ttk.Frame(tabs, padding=5)
        tabs.add(calibration, text="标定与测试")
        tabs.add(records, text="40路明细")
        edit_canvas = tk.Canvas(calibration, highlightthickness=0, width=320)
        edit_scroll = ttk.Scrollbar(calibration, orient="vertical", command=edit_canvas.yview)
        edit_scroll.pack(side="right", fill="y")
        edit_canvas.configure(yscrollcommand=edit_scroll.set)
        edit_canvas.pack(side="left", fill="both", expand=True)
        edit = ttk.Frame(edit_canvas)
        edit_id = edit_canvas.create_window(0, 0, window=edit, anchor="nw")
        edit.bind("<Configure>", lambda _: edit_canvas.configure(scrollregion=edit_canvas.bbox("all")))
        edit_canvas.bind("<Configure>", lambda event: edit_canvas.itemconfigure(edit_id, width=event.width))
        chosen = ttk.LabelFrame(edit, text="1 · 选择控制板 FPC / 逻辑通道", padding=8)
        chosen.pack(fill="x")
        ttk.Label(chosen, text="控制板 FPC").grid(row=0, column=0, sticky="w")
        self.fpc_box = ttk.Combobox(chosen, state="readonly", textvariable=self.fpc,
                                    values=[str(i) for i in range(1, 11)], width=7)
        self.fpc_box.grid(row=0, column=1, padx=6)
        self.fpc_box.bind("<<ComboboxSelected>>", lambda _: self.choose_fpc())
        ttk.Label(chosen, text="逻辑通道").grid(row=1, column=0, sticky="w", pady=5)
        self.channel_box = ttk.Spinbox(chosen, from_=1, to=40, textvariable=self.channel,
                                       width=7, command=self.choose_channel)
        self.channel_box.grid(row=1, column=1, padx=6)
        self.channel_box.bind("<Return>", lambda _: self.choose_channel())
        self.channel_box.bind("<FocusOut>", lambda _: self.choose_channel())
        ttk.Label(chosen, textvariable=self.description, wraplength=300).grid(row=2, column=0, columnspan=2, sticky="w")
        ttk.Label(chosen, text="CH1–40 为逻辑输出，不是 FPC 针脚号。", foreground="#805522").grid(row=3, column=0, columnspan=2, sticky="w", pady=(4, 0))

        binding = ttk.LabelFrame(edit, text="2 · 绑定 RIS 端的 4列×10行接口", padding=8)
        binding.pack(fill="x", pady=6)
        self.port_box = ttk.Combobox(binding, textvariable=self.port, state="readonly",
                                     values=[f"{p} · {port_label(p)}" for p in PORTS], width=29)
        self.port_box.pack(fill="x")
        row = ttk.Frame(binding)
        row.pack(fill="x", pady=(4, 0))
        button(row, text="绑定所选接口", command=self.bind_port).pack(side="left")
        button(row, text="清除此 FPC", command=self.clear_fpc).pack(side="left", padx=4)
        button(binding, text="按接线表补全已绑定接口", command=self.generate_wiring).pack(fill="x", pady=(5, 0))
        ttk.Label(binding, text="正面：上端 U4→U1，下端 U1→U4；\n两半区行号已按实测翻转，FPC同号直通。", wraplength=300).pack(anchor="w", pady=(4, 0))

        test = ttk.LabelFrame(edit, text="3 · 测试输出并记录实际对应单元", padding=8)
        test.pack(fill="x")
        self.test_button = button(test, text="选择单路测试 · 其余399路低", command=self.test_channel)
        self.test_button.pack(fill="x")
        self.test_group_button = button(test, text="选择当前FPC的40路测试", command=self.test_fpc)
        self.test_group_button.pack(fill="x", pady=(3, 0))
        ttk.Checkbutton(test, text="记录后选择下一通道", variable=self.auto_next).pack(anchor="w", pady=(4, 0))
        ttk.Checkbutton(test, text="记录后预选下路测试（需总下发）", variable=self.auto_test).pack(anchor="w")
        self.measured_check = ttk.Checkbutton(test, text="按已实测结果记录（需测试成功）", variable=self.measured)
        self.measured_check.pack(anchor="w")
        ttk.Radiobutton(test, text="点击阵列：记录当前通道的映射", variable=self.record_mode, value=True).pack(anchor="w", pady=(5, 0))
        ttk.Radiobutton(test, text="点击阵列：只选择 / 查看单元", variable=self.record_mode, value=False).pack(anchor="w")

        cell = ttk.LabelFrame(edit, text="所选 RIS 单元", padding=8)
        cell.pack(fill="x", pady=6)
        ttk.Label(cell, textvariable=self.selected_cell, wraplength=300).pack(anchor="w")
        row = ttk.Frame(cell)
        row.pack(fill="x", pady=(4, 0))
        self.high_button = button(row, text="选择单元高", command=lambda: self.control_cell(1))
        self.high_button.pack(side="left")
        self.low_button = button(row, text="选择单元低", command=lambda: self.control_cell(0))
        self.low_button.pack(side="left", padx=4)
        cell.pack_configure(before=chosen)

        ttk.Label(records, textvariable=self.description, wraplength=300).pack(anchor="w", pady=4)
        listing = ttk.LabelFrame(records, text="当前 FPC 的40路记录", padding=5)
        button(records, text="移除当前通道记录（可撤销）", command=self.remove_channel).pack(side="bottom", fill="x", pady=(4, 0))
        listing.pack(fill="both", expand=True)
        horizontal = ttk.Scrollbar(listing, orient="horizontal")
        horizontal.pack(side="bottom", fill="x")
        self.table = ttk.Treeview(listing, columns=("channel", "cell", "chip", "pin", "fpc_pin", "header", "verified"), show="headings", height=8)
        for column, title, width in (("channel", "通道", 50), ("cell", "RIS 行列", 90), ("chip", "595输出", 65),
                                     ("pin", "芯片脚", 50), ("fpc_pin", "FPC针", 50), ("header", "小板排针", 75),
                                     ("verified", "依据/实测", 105)):
            self.table.heading(column, text=title)
            self.table.column(column, width=width, minwidth=width, stretch=False)
        horizontal.configure(command=self.table.xview)
        self.table.configure(xscrollcommand=horizontal.set)
        scroll = ttk.Scrollbar(listing, orient="vertical", command=self.table.yview)
        scroll.pack(side="right", fill="y")
        self.table.configure(yscrollcommand=scroll.set)
        self.table.pack(fill="both", expand=True)
        self.table.bind("<<TreeviewSelect>>", self.select_table)

    def selected_source(self):
        fpc, channel = int(self.fpc.get()), int(self.channel.get())
        source(fpc, channel)
        return fpc, channel

    def set_notice(self, text):
        self.notice.set(text)

    def _select_cell(self, cell):
        if cell != self.cell:
            self.previous_cell, self.cell = self.cell, cell

    def _select_source_cell(self):
        try:
            value = self.model.channels.get(self.selected_source())
        except ValueError:
            value = None
        self._select_cell((value["row"], value["column"]) if value else None)

    def change(self, operation):
        candidate = self.model.copy()
        try:
            operation(candidate)
        except (ValueError, TypeError) as error:
            self.set_notice(str(error))
            return False
        if candidate.document() == self.model.document():
            return True
        self.history.append((self.model, self.path))
        self.history = self.history[-100:]
        self.model = candidate
        self.dirty = True
        self.autosave()
        self.refresh()
        return True

    def autosave(self):
        try:
            self.storage_dir.mkdir(parents=True, exist_ok=True)
            self.model.save(self.recovery_path)
            self.recovery_error = ""
        except OSError as error:
            self.recovery_error = str(error)
            self.set_notice(f"恢复草稿保存失败，请手动保存：{error}")

    def choose_fpc(self, fpc=None):
        if fpc is not None:
            self.fpc.set(str(fpc))
        try:
            fpc, _ = self.selected_source()
        except ValueError:
            return
        remaining = self.model.pending(fpc)
        self.channel.set(str(remaining[0] if remaining else 1))
        self._select_source_cell()
        self.refresh()

    def choose_channel(self):
        try:
            self.selected_source()
        except ValueError:
            self.set_notice("逻辑通道需要在1–40之间")
            return
        self._select_source_cell()
        self.refresh()

    def select_table(self, _event=None):
        selection = self.table.selection()
        if selection and self.channel.get() != selection[0]:
            self.channel.set(selection[0])
            self.choose_channel()

    def bind_port(self):
        try:
            fpc, _ = self.selected_source()
            port = self.port.get().split(" · ", 1)[0]
        except ValueError as error:
            self.set_notice(str(error))
            return
        if self.change(lambda model: model.bind_wiring(fpc, port)):
            self._select_source_cell()
            self.refresh()
            self.set_notice(f"已绑定 FPC{fpc} → {port_label(port)}，已生成40路接线表映射；未自动标为实测")

    def generate_wiring(self):
        if self.change(lambda model: model.generate_wiring()):
            self._select_source_cell()
            self.refresh()
            self.set_notice(f"已按接线表补全 {len(self.model.ports)} 个接口，共 {self.model.count()} 路；已有记录及实测状态保留")

    def clear_fpc(self):
        try:
            fpc, _ = self.selected_source()
        except ValueError:
            return
        if self.change(lambda model: model.unbind(fpc)):
            self._select_source_cell()
            self.refresh()
            self.set_notice(f"已解除 FPC{fpc} 的接口及通道映射，可撤销")

    def remove_channel(self):
        try:
            key = self.selected_source()
        except ValueError:
            return
        if self.change(lambda model: model.remove(*key)):
            self._select_source_cell()
            self.refresh()
            self.set_notice(f"已移除 FPC{key[0]} / CH{key[1]:02d} 的记录，可撤销")

    def has_probe(self):
        if not self.probed or not self.app.connected or not self.app.latest:
            return False
        reply = self.app.latest
        return (reply["oe"] and reply["blink_ms"] == 0 and not active_frequency(reply) and reply["errors"] == 0 and
                reply["image"].upper() == probe_command(*self.probed).split()[1])

    def test_channel(self, feature=None):
        try:
            key = self.selected_source()
        except ValueError as error:
            self.set_notice(str(error))
            return
        command = probe_command(*key)

        def completed(reply, error):
            if not self.alive:
                return
            if error or not reply or not reply["ok"] or reply["errors"] or not reply["oe"] or reply["blink_ms"] or active_frequency(reply) or reply["image"].upper() != command.split()[1]:
                self.probed = None
                self.set_notice("测试输出未确认；请检查主界面的连接、错误标志和状态")
            else:
                self.probed = key
                self.set_notice(f"命令已确认：仅 FPC{key[0]} / CH{key[1]:02d} 置高；请实测并点击实际对应单元")
            self.update_state()

        if self.app.command(command, callback=completed, feature=feature,
                            summary=f"单路测试 · FPC{key[0]} / CH{key[1]:02d} 高，其余399路低",
                            mapping_document=self.model.document()):
            self.set_notice(f"已配置 FPC{key[0]} / CH{key[1]:02d} 单路测试；点击总按钮下发后再实测。")

    def all_low(self):
        if self.app.command("ALL 0", callback=self._zero_done):
            self.set_notice("已选择全板置低；点击总按钮后结束测试。")

    def test_fpc(self):
        try:
            fpc, _ = self.selected_source()
        except ValueError:
            return
        command = fpc_probe_command(fpc)
        def completed(reply, error):
            if not self.alive:
                return
            self.probed = None
            if error or not reply or not reply["ok"] or not reply["oe"] or reply["image"].upper() != command.split()[1]:
                self.set_notice("FPC组测试输出未确认，请检查连接")
            else:
                self.set_notice(f"仅 FPC{fpc} 的40路已命令置高；请识别实际接口。逐点标定前改用单通道测试。")
            self.update_state()
        if self.app.command(command, callback=completed, summary=f"FPC{fpc} 的40路高，其余360路低",
                            mapping_document=self.model.document()):
            self.set_notice(f"已配置 FPC{fpc} 的40路测试；经右上角总按钮应用。")

    def _zero_done(self, reply, error):
        if self.alive:
            self.probed = None
            self.set_notice("已确认全板置低" if not error and reply and reply["ok"] else "全低结果未确认，请检查连接")
            self.update_state()

    def record(self, row, column):
        try:
            key = self.selected_source()
        except ValueError as error:
            self.set_notice(str(error))
            return False
        verified = self.measured.get()
        if verified and (not self.has_probe() or self.probed != key):
            self.set_notice("记录实测映射前，需要先成功测试当前所选通道")
            return False
        if not self.change(lambda model: model.assign(*key, row, column, verified)):
            return False
        self.set_notice(f"已记录 FPC{key[0]} / CH{key[1]:02d} → R{row:02d} C{column:02d}（{'实测确认' if verified else '待核对'}）")
        if self.auto_next.get():
            pending = set(self.model.pending(key[0]))
            remaining = [c for c in range(key[1] + 1, 41) if c in pending]
            remaining += [c for c in range(1, key[1]) if c in pending]
            if remaining:
                self.channel.set(str(remaining[0]))
                self._select_source_cell()
                self.refresh()
                if self.auto_test.get():
                    self._schedule_test(self.selected_source())
            else:
                self.set_notice(f"FPC{key[0]} 已记录40/40路；请保存并选择下一个FPC。当前输出保持，结束可点全板置低。")
        return True

    def _schedule_test(self, key):
        """Auto-next only prepares a draft; it never schedules a hardware write."""
        if self.follow_timer:
            self.frame.after_cancel(self.follow_timer)
            self.follow_timer = None
        if self.alive and self.selected_source() == key:
            self.test_channel(feature="settings")

    def control_cell(self, high):
        if not self.cell:
            return
        key = self.model.at(*self.cell)
        value = self.model.channels.get(key)
        if not value or not (value["verified"] or value["basis"] == "wiring"):
            self.set_notice("此单元需要接线表映射或实测确认的手动映射")
            return
        info = source(*key)
        if self.app.command(f"BIT {info['chip']} {info['bit']} {high}",
                            summary=f"R{self.cell[0]:02d} C{self.cell[1]:02d} → {'高 · 1' if high else '低 · 0'}（其余保持）",
                            mapping_document=self.model.document()):
            self.set_notice(f"已配置 R{self.cell[0]:02d} C{self.cell[1]:02d} 的电平；经右上角总按钮应用。")

    def update_state(self):
        if not self.alive:
            return
        connected = self.app.connected
        available = True  # Configuring an output does not require a connection.
        self.connection.set(f"共享连接：{self.app.host.get()}:{self.app.port.get()} · {'已连接' if connected else '未连接'}")
        for button in (self.test_button, self.test_group_button, self.zero_button):
            button.configure(state="normal" if available else "disabled")
        if not connected or not self.app.latest:
            output = "板端输出：未连接，电平状态未确认"
        else:
            reply = self.app.latest
            image = bytes.fromhex(reply["image"])
            count = sum(bin(value).count("1") for value in image)
            if not reply["oe"]:
                output = "板端已确认：OE禁能，输出高阻"
            elif active_frequency(reply):
                output = f"板端高速模式：400路全0/全1 · {frequency_text(active_frequency(reply))} · 图案镜像不代表瞬时电平"
            elif count == 0:
                output = "板端已确认：400路全部低"
            elif count == 1:
                index = next(i * 8 + bit for i, value in enumerate(image) for bit in range(8) if value & (1 << bit))
                output = f"板端已确认：仅 FPC{index // 40 + 1} / CH{index % 40 + 1:02d} 高，其余399路低"
            else:
                group = next((i for i in range(1, 11) if reply["image"].upper() == fpc_probe_command(i).split()[1]), None)
                output = f"板端已确认：仅 FPC{group} 的40路高，其余360路低" if group else f"板端已确认：{count}/400路高（非单通道测试）"
            if reply["blink_ms"]:
                output += f" · 正在定时切换 {reply['blink_ms']} ms"
        self.output_state.set(output)
        if self.probed and not self.has_probe():
            self.probed = None
        try:
            verified_available = self.has_probe() and self.probed == self.selected_source()
        except ValueError:
            verified_available = False
        self.measured_check.configure(state="normal" if verified_available or self.measured.get() else "disabled")
        key = self.model.at(*self.cell) if self.cell else None
        value = self.model.channels.get(key)
        can_control = available and value and (value["verified"] or value["basis"] == "wiring")
        for button in (self.high_button, self.low_button):
            button.configure(state="normal" if can_control else "disabled")
        self.draw()

    def refresh(self):
        if not self.alive:
            return
        total, verified = self.model.count(), self.model.count(verified=True)
        filename = self.path.name if self.path else "未命名"
        self.progress.set(f"{filename}{' · 有未保存修改' if self.dirty else ''}   |   接口 {len(self.model.ports)}/10   |   通道 {total}/400   |   实测确认 {verified}/400" +
                          ("   |   恢复草稿保存失败，请手动保存" if self.recovery_error else ""))
        try:
            fpc, channel = self.selected_source()
        except ValueError:
            return
        info = pin_trace(fpc, channel)
        self.description.set(f"FPC{fpc} / CH{channel:02d} · 全局输出 {info['output']:03d}\n"
                             f"595：{info['reference']}.Q{info['bit']} · 芯片第{info['chip_pin']}脚\n"
                             f"FPC第{info['fpc_pin']}针 → 小板排针{info['header']}第{info['header_pin']}针\n"
                             f"此FPC已映射 {self.model.count(fpc)}/40 · 实测 {self.model.count(fpc, verified=True)}/40")
        bound = self.model.ports.get(fpc)
        self.port.set(f"{bound} · {port_label(bound)}" if bound else "")
        self.table.delete(*self.table.get_children())
        for c in range(1, 41):
            value = self.model.channels.get((fpc, c))
            trace = pin_trace(fpc, c)
            self.table.insert("", "end", iid=str(c), values=(f"CH{c:02d}",
                              f"R{value['row']:02d} C{value['column']:02d}" if value else "—",
                              f"{trace['reference']}.Q{trace['bit']}", trace["chip_pin"], trace["fpc_pin"],
                              f"{trace['header']}.{trace['header_pin']}", record_status(value)))
        self.table.selection_set(str(channel))
        self.table.see(str(channel))
        self._cell_description()
        self.update_state()

    def _cell_description(self):
        if not self.cell:
            self.selected_cell.set("尚未选择 RIS 单元")
            return
        row, column = self.cell
        key = self.model.at(row, column)
        text = f"R{row:02d} C{column:02d} · {port_label(cell_port(row, column))}"
        if key:
            info = pin_trace(*key)
            text += (f"\nFPC{key[0]} / CH{key[1]:02d} · FPC第{info['fpc_pin']}针"
                     f"\n595：{info['reference']}.Q{info['bit']} · 芯片第{info['chip_pin']}脚"
                     f"\n小板排针：{info['header']} 第{info['header_pin']}针"
                     f"\n控制板 {info['control_net']} → 小板 {info['adapter_net']}"
                     f"\n依据：{record_status(self.model.channels[key])}")
        else:
            text += "\n尚未记录控制通道"
        self.selected_cell.set(text)

    def draw(self):
        if not self.alive:
            return
        self.topology.draw()
        changed = getattr(self.app, "mapping_updated", None)
        if changed:
            changed()

    @property
    def grid_geometry(self):
        return self.topology.grid_geometry

    @property
    def hit_fpcs(self):
        return self.topology.hit_fpcs

    @property
    def hit_ports(self):
        return self.topology.hit_ports

    def hit_cell(self, x, y):
        return self.topology.hit_cell(x, y)

    def click(self, event):
        x, y = self.canvas.canvasx(event.x), self.canvas.canvasy(event.y)
        for left, top, right, bottom, fpc in self.hit_fpcs:
            if left <= x <= right and top <= y <= bottom:
                self.choose_fpc(fpc)
                return
        for left, top, right, bottom, port in self.hit_ports:
            if left <= x <= right and top <= y <= bottom:
                self.port.set(f"{port} · {port_label(port)}")
                self.set_notice(f"选中 {port_label(port)}；点击“绑定所选接口”确认连接关系")
                return
        cell = self.hit_cell(x, y)
        if cell:
            old_selection = self.cell, self.previous_cell
            self._select_cell(cell)
            if self.record_mode.get():
                if not self.record(*cell):
                    self.cell, self.previous_cell = old_selection
            else:
                key = self.model.at(*cell)
                if key:
                    self.fpc.set(str(key[0]))
                    self.channel.set(str(key[1]))
                    self.refresh()
            self._cell_description()
            self.update_state()

    def motion(self, event):
        x, y = self.canvas.canvasx(event.x), self.canvas.canvasy(event.y)
        for left, top, right, bottom, port in self.hit_ports:
            if left <= x <= right and top <= y <= bottom:
                owner = next((fpc for fpc, bound in self.model.ports.items() if bound == port), None)
                self.hover.set(f"{port} · {port_label(port)} · " + (f"已绑定控制板 FPC{owner}" if owner else "未绑定"))
                return
        cell = self.hit_cell(x, y)
        if cell:
            key = self.model.at(*cell)
            text = f"R{cell[0]:02d} C{cell[1]:02d} · {port_label(cell_port(*cell))}"
            if key:
                info = pin_trace(*key)
                text += (f" → FPC{key[0]}/CH{key[1]:02d} · 595 {info['reference']}.Q{info['bit']} 第{info['chip_pin']}脚"
                         f" · FPC针{info['fpc_pin']} · 小板{info['header']}.{info['header_pin']} · {record_status(self.model.channels[key])}")
            else:
                text += " · 未映射"
            self.hover.set(text)

    def undo(self):
        if self.history:
            self.model, self.path = self.history.pop()
            self.dirty = True
            self.autosave()
            self._select_source_cell()
            self.refresh()
            self.set_notice("已撤销上一次映射修改；硬件输出未随撤销改变")

    def _may_discard(self):
        if not self.dirty:
            return True
        answer = messagebox.askyesnocancel("保存映射", "映射有未保存修改，是否先保存？", parent=self.frame)
        if answer is None:
            return False
        return self.save() if answer else True

    def new(self):
        if self._may_discard():
            self.history.append((self.model, self.path))
            self.model = RisMapping()
            self.path = None
            self.dirty = False
            self.cell = self.previous_cell = None
            self.refresh()
            self.set_notice("已新建空映射；未自动假设任何 FPC 与单元对应关系")

    def save(self):
        path = self.path
        if path is None:
            try:
                self.storage_dir.mkdir(parents=True, exist_ok=True)
            except OSError as error:
                messagebox.showerror("保存失败", str(error), parent=self.frame)
                return False
            picked = filedialog.asksaveasfilename(parent=self.frame, initialdir=self.storage_dir,
                                                 initialfile="ris_mapping.json", defaultextension=".json",
                                                 filetypes=[("RIS 映射", "*.json")])
            if not picked:
                return False
            path = Path(picked)
        try:
            path.parent.mkdir(parents=True, exist_ok=True)
            self.model.save(path)
        except OSError as error:
            messagebox.showerror("保存失败", str(error), parent=self.frame)
            return False
        self.path = path
        self.dirty = False
        self.model.migration_message = ""
        self.refresh()
        self.set_notice(f"已保存 {path}")
        return True

    def load_path(self, path, recovery=False):
        try:
            model = RisMapping.load(path)
        except (OSError, ValueError, TypeError) as error:
            self.set_notice(f"未载入文件，当前映射保留：{error}")
            return False
        self.history.append((self.model, self.path))
        self.model = model
        # Imported originals are read-only inputs; future saves target this copy.
        self.path = None if recovery else self.storage_dir / Path(path).name
        self.dirty = recovery or bool(model.migration_message)
        self.probed = None
        if self.follow_timer:
            self.frame.after_cancel(self.follow_timer)
            self.follow_timer = None
        if model.migration_message:
            self.autosave()
        self._select_source_cell()
        self.refresh()
        self.set_notice(model.migration_message or f"已载入 {'恢复草稿' if recovery else path}；未向板卡发送命令")
        return True

    def load(self):
        if not self._may_discard():
            return
        picked = filedialog.askopenfilename(parent=self.frame, initialdir=self.storage_dir if self.storage_dir.exists() else Path.cwd(),
                                            filetypes=[("RIS 映射", "*.json")])
        if picked:
            self.load_path(picked)

    def recover(self):
        if self.recovery_path.exists() and self._may_discard():
            self.load_path(self.recovery_path, recovery=True)
        elif not self.recovery_path.exists():
            self.set_notice("尚无恢复草稿；每次映射修改后会自动保存恢复草稿")

    def export_csv(self):
        picked = filedialog.asksaveasfilename(parent=self.frame, initialfile="ris_mapping.csv", defaultextension=".csv",
                                             filetypes=[("映射表", "*.csv")])
        if picked:
            try:
                self.model.export_csv(picked)
                self.set_notice(f"已导出400路表格：{picked}；未映射项留空")
            except OSError as error:
                self.set_notice(f"CSV 导出失败：{error}")

    def close(self, discard=False):
        if not self.alive:
            return True
        if not discard and not self._may_discard():
            return False
        self.alive = False
        if self.follow_timer:
            self.frame.after_cancel(self.follow_timer)
        self.frame.destroy()
        return True
