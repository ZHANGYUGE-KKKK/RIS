"""Manual RIS cell control using the mapping editor's state and TCP worker."""
from ris_frequency import active_frequency, frequency_text
import tkinter as tk
from tkinter import ttk

from ris_mapping import pin_trace
from ris_topology import TopologyView


class ManualControl:
    def __init__(self, app, page, parent):
        self.app, self.page = app, page
        self.row = tk.StringVar(value="1")
        self.column = tk.StringVar(value="1")
        self.level = tk.StringVar(value="所选单元电平：尚未确认")
        self.last_cell = None
        self.last_source = None
        panes = ttk.Panedwindow(parent, orient="horizontal")
        panes.pack(fill="both", expand=True)
        visual = ttk.Frame(panes)
        panes.add(visual, weight=4)
        self.canvas = tk.Canvas(visual, background="#f6f8fb", highlightthickness=0)
        self.topology = TopologyView(page, self.canvas)
        scroll = ttk.Scrollbar(visual, orient="vertical", command=self.canvas.yview)
        scroll.pack(side="right", fill="y")
        self.canvas.configure(yscrollcommand=scroll.set)
        self.canvas.pack(fill="both", expand=True)
        self.canvas.bind("<Configure>", lambda _: self.refresh())
        self.canvas.bind("<Button-1>", self.click)
        self.canvas.bind("<Motion>", self.motion)

        side = ttk.Frame(panes, width=320, padding=(10, 0, 0, 0))
        panes.add(side, weight=0)
        side_canvas = tk.Canvas(side, width=315, highlightthickness=0)
        side_scroll = ttk.Scrollbar(side, orient="vertical", command=side_canvas.yview)
        side_scroll.pack(side="right", fill="y")
        side_canvas.configure(yscrollcommand=side_scroll.set)
        side_canvas.pack(side="left", fill="both", expand=True)
        edit = ttk.Frame(side_canvas)
        edit_id = side_canvas.create_window(0, 0, anchor="nw", window=edit)
        edit.bind("<Configure>", lambda _: side_canvas.configure(scrollregion=side_canvas.bbox("all")))
        side_canvas.bind("<Configure>", lambda event: side_canvas.itemconfigure(edit_id, width=event.width))

        locator = ttk.LabelFrame(edit, text="手动选择 RIS 单元", padding=8)
        locator.pack(fill="x")
        inputs = ttk.Frame(locator)
        inputs.pack(fill="x")
        for label, variable in (("行", self.row), ("列", self.column)):
            ttk.Label(inputs, text=label).pack(side="left")
            box = ttk.Spinbox(inputs, from_=1, to=20, textvariable=variable, width=4, command=self.locate)
            box.pack(side="left", padx=(4, 10))
            box.bind("<Return>", lambda _: self.locate())
        ttk.Button(inputs, text="定位", style="Mapping.TButton", command=self.locate).pack(side="left")
        step = ttk.Frame(locator)
        step.pack(fill="x", pady=(5, 0))
        ttk.Button(step, text="上一单元", style="Mapping.TButton", command=lambda: self.step(-1)).pack(side="left")
        ttk.Button(step, text="下一单元", style="Mapping.TButton", command=lambda: self.step(1)).pack(side="left", padx=4)
        ttk.Label(locator, text="也可直接点击阵列；选择不会改变输出。", wraplength=290).pack(anchor="w", pady=(5, 0))
        output = ttk.LabelFrame(edit, text="手动电平 / 接线检查", padding=8)
        output.pack(fill="x", pady=6)
        levels = ttk.Frame(output)
        levels.pack(fill="x")
        self.high_button = ttk.Button(levels, text="选择单元高", style="Mapping.TButton", command=lambda: self.control(1))
        self.high_button.pack(side="left")
        self.low_button = ttk.Button(levels, text="选择单元低", style="Mapping.TButton", command=lambda: self.control(0))
        self.low_button.pack(side="left", padx=4)
        ttk.Label(output, text="只改变所选单元，其余单元保持。", wraplength=290).pack(anchor="w", pady=(3, 6))
        self.test_button = ttk.Button(output, text="选择单路测试 · 其余399路低", style="Mapping.TButton", command=self.test_cell)
        self.test_button.pack(fill="x")
        self.zero_button = ttk.Button(output, text="选择结束检查 · 全板置低", style="Mapping.TButton", command=page.all_low)
        self.zero_button.pack(fill="x", pady=(4, 0))
        ttk.Label(output, textvariable=self.level, foreground="#315c74", wraplength=290).pack(anchor="w", pady=(5, 0))
        detail = ttk.LabelFrame(edit, text="所选单元的接线路径", padding=8)
        detail.pack(fill="x")
        ttk.Label(detail, textvariable=page.selected_cell, wraplength=290).pack(anchor="w")
        ttk.Label(edit, textvariable=page.progress, wraplength=290).pack(anchor="w", pady=6)
        ttk.Label(edit, textvariable=page.output_state, foreground="#315c74", wraplength=290).pack(anchor="w", pady=6)
        ttk.Label(edit, textvariable=page.notice, foreground="#245c85", wraplength=290).pack(anchor="w")
        ttk.Label(edit, text="先选择电平或单路测试，再点击右上角总按钮；等待板端确认后读万用表。", wraplength=290).pack(anchor="w", pady=6)
        ttk.Checkbutton(edit, text="加深其他连线", variable=page.emphasize_connections,
                        command=page.draw).pack(anchor="w", pady=6)
        self.refresh()

    def select_cell(self, row, column):
        if not (1 <= row <= 20 and 1 <= column <= 20):
            self.page.set_notice("行号、列号都需要在1–20之间")
            return False
        page = self.page
        page._select_cell((row, column))
        self.row.set(str(row))
        self.column.set(str(column))
        key = page.model.at(row, column)
        if key:
            page.fpc.set(str(key[0]))
            page.channel.set(str(key[1]))
        page.refresh()
        if key:
            page.set_notice(f"已定位 R{row:02d} C{column:02d}；选择电平或单路测试，经右上角总按钮应用")
        else:
            page.set_notice(f"R{row:02d} C{column:02d} 尚未映射，请先打开映射、恢复草稿或到映射页绑定接口")
        self.see_selected()
        return True

    def see_selected(self):
        if not self.page.cell:
            return
        x0, y0, pitch, gap = self.topology.grid_geometry
        row, _column = self.page.cell
        y = y0 + (row - .5) * pitch + (gap if row > 10 else 0)
        top, height = self.canvas.canvasy(0), self.canvas.winfo_height()
        if y < top + pitch or y > top + height - pitch:
            region = self.canvas.tk.splitlist(self.canvas.cget("scrollregion"))
            self.canvas.yview_moveto(max(0, y - height / 2) / float(region[3]))

    def locate(self):
        try:
            row, column = int(self.row.get()), int(self.column.get())
        except ValueError:
            self.page.set_notice("请输入1–20的整数行号和列号")
            return False
        return self.select_cell(row, column)

    def step(self, direction):
        row, column = self.page.cell or (1, 1)
        index = ((row - 1) * 20 + column - 1 + direction) % 400
        self.select_cell(index // 20 + 1, index % 20 + 1)

    def click(self, event):
        x, y = self.canvas.canvasx(event.x), self.canvas.canvasy(event.y)
        for left, top, right, bottom, fpc in self.topology.hit_fpcs:
            if left <= x <= right and top <= y <= bottom:
                self.page.choose_fpc(fpc)
                return
        for left, top, right, bottom, port in self.topology.hit_ports:
            if left <= x <= right and top <= y <= bottom:
                owner = next((fpc for fpc, bound in self.page.model.ports.items() if bound == port), None)
                if owner:
                    self.page.choose_fpc(owner)
                else:
                    self.page.set_notice(f"{port} 尚未绑定，请到“FPC—RIS 映射”页绑定")
                return
        cell = self.topology.hit_cell(x, y)
        if cell:
            self.select_cell(*cell)

    def motion(self, event):
        cell = self.topology.hit_cell(self.canvas.canvasx(event.x), self.canvas.canvasy(event.y))
        if cell:
            key = self.page.model.at(*cell)
            text = f"R{cell[0]:02d} C{cell[1]:02d}"
            if key:
                info = pin_trace(*key)
                text += f" → FPC{key[0]}/CH{key[1]:02d} · {info['reference']}.Q{info['bit']} · 芯片第{info['chip_pin']}脚"
            self.page.hover.set(text if key else text + " · 尚未映射")

    def can_control(self):
        cell = self.page.cell
        key = self.page.model.at(*cell) if cell else None
        entry = self.page.model.channels.get(key)
        return bool(entry and (entry["basis"] == "wiring" or entry["verified"]))

    def control(self, high):
        if self.can_control():
            self.page.control_cell(high)

    def test_cell(self):
        if not self.can_control():
            return
        # Resolve the selected cell again instead of trusting an old FPC selection.
        key = self.page.model.at(*self.page.cell)
        self.page.fpc.set(str(key[0]))
        self.page.channel.set(str(key[1]))
        self.page.refresh()
        self.page.test_channel()

    def refresh(self):
        if not self.page.alive:
            return
        if self.page.cell != self.last_cell:
            self.last_cell = self.page.cell
            if self.last_cell:
                self.row.set(str(self.last_cell[0]))
                self.column.set(str(self.last_cell[1]))
        available = True
        for button in (self.high_button, self.low_button, self.test_button):
            button.configure(state="normal" if available and self.can_control() else "disabled")
        self.zero_button.configure(state="normal" if available else "disabled")
        key = self.page.model.at(*self.page.cell) if self.page.cell else None
        if key != self.last_source:
            self.last_source = key
            if key:
                self.app.chip.set(str(pin_trace(*key)["chip"] + 1))
                self.app.select_chip(redraw=False)
        latest = self.app.latest
        level = "所选单元电平：尚未确认"
        if key and self.app.connected and latest:
            info = pin_trace(*key)
            image = bytes.fromhex(latest["image"])
            value = (image[info["chip"]] >> info["bit"]) & 1
            level = f"所选单元命令镜像：{'高 · 1' if value else '低 · 0'}" if latest["oe"] else "所选单元：输出禁能 · 高阻"
            if latest["blink_ms"]:
                level += " · 定时切换中"
            if active_frequency(latest) and latest["oe"]:
                level = f"所选单元：0/1高速切换中 · {frequency_text(active_frequency(latest))}，瞬时电平未回读"
            if not latest["ok"] or latest["errors"]:
                level += " · 板端报错，请查看状态"
        self.level.set(level)
        self.topology.draw()
