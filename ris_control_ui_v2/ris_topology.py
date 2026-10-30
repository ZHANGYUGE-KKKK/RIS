"""Shared RIS topology renderer; selections and mapping belong to MappingPage."""
from ris_frequency import active_frequency
from ris_mapping import PORTS, cell_port, source

COLORS = ("#277da8", "#bc6c25", "#7b5aa6", "#23856c", "#c05266",
          "#4d68b0", "#9a791c", "#477947", "#ad548c", "#367d89")
LIGHT_COLORS = ("#e3f0f7", "#fbefdf", "#f0eaf8", "#e4f2ed", "#f9e8ed",
                "#e8ecfa", "#f7f0d7", "#e9f2e6", "#f6e8f2", "#e6f0f3")


def faded_color(color, opacity=0.6):
    background = "#f6f8fb"
    return "#" + "".join(f"{round(int(color[i:i + 2], 16) * opacity + int(background[i:i + 2], 16) * (1 - opacity)):02x}"
                         for i in (1, 3, 5))


class TopologyView:
    """Render shared state on one canvas, retaining independent hit geometry."""

    def __init__(self, state, canvas):
        self.state = state
        self.canvas = canvas
        self.hit_ports = []
        self.hit_fpcs = []

    def draw(self, preview=None, focus=None):
        if not self.state.alive:
            return
        canvas = self.canvas
        canvas.delete("all")
        width, height = max(canvas.winfo_width(), 600), max(canvas.winfo_height(), 500)
        canvas.configure(scrollregion=(0, 0, width, height))
        pitch = min((width - 200) / 20, (height - 180) / 20)
        x0 = 180 + (width - 185 - 20 * pitch) / 2
        y0, gap = (height - 20 * pitch - 16) / 2, 16
        self.grid_geometry = x0, y0, pitch, gap
        self.hit_ports = []
        self.hit_fpcs = []
        try:
            fpc, channel = self.state.selected_source()
        except ValueError:
            fpc, channel = 1, 1
        reverse_ports = {value: key for key, value in self.state.model.ports.items()}
        canvas.create_text(x0 + pitch * 20 + 18, y0 - 35, text="BIAS / 上端\n拓扑图正视方向",
                           anchor="w", font=("sans", 9, "bold"), fill="#334860")
        bound = self.state.model.ports.get(fpc)
        canvas.create_text(17, y0 - 30, text=f"FPC{fpc} → {bound}" if bound else f"FPC{fpc} · 未绑定接口",
                           anchor="w", font=("sans", 9, "bold"), fill=COLORS[fpc - 1])
        canvas.create_rectangle(8, y0 - 12, 139, y0 + 20 * pitch + gap + 12, fill="#e7ecf3", outline="#c2cedd")
        canvas.create_text(73, y0 + 4, text="控制板", font=("sans", 11, "bold"), fill="#293e55")
        fpc_centers = {}
        for i in range(1, 11):
            cy = y0 + 28 + (i - 1) * (20 * pitch + gap - 44) / 9
            rect = (17, cy - 16, 130, cy + 16)
            fpc_centers[i] = 130, cy
            self.hit_fpcs.append((*rect, i))
            active = i == fpc
            bound_port = self.state.model.ports.get(i)
            background = COLORS[i - 1] if active else (LIGHT_COLORS[i - 1] if bound_port else "#f0f2f5")
            border = {"outline": COLORS[i - 1], "width": 2} if active or bound_port else {
                "outline": "#b9c4d0", "width": 1, "dash": (3, 3)}
            canvas.create_rectangle(*rect, fill=background, **border)
            if bound_port and not active:
                canvas.create_rectangle(rect[0], rect[1], rect[0] + 4, rect[3],
                                        fill=COLORS[i - 1], outline="")
            canvas.create_text(73, cy - 7, text=f"FPC{i}   {self.state.model.count(i)}/40",
                               fill="white" if active else ("#293e55" if bound_port else "#778391"),
                               font=("sans", 9, "bold"))
            canvas.create_text(73, cy + 8, text=f"已绑定 {bound_port}" if bound_port else "未绑定",
                               fill="white" if active else ("#246348" if bound_port else "#778391"),
                               font=("sans", 8, "bold"))
        port_geometry = {}
        for port in PORTS:
            lane = int(port[1]) - 1
            px = x0 + (lane * 4 + 2) * pitch
            py = y0 - 35 if port[0] == "T" else y0 + 20 * pitch + gap + 31
            rect = (px - pitch * 1.9, py - 13, px + pitch * 1.9, py + 13)
            port_geometry[port] = px, py, rect

        # Route outside the array and enter the outer edge of each port. Further
        # ports use outer tracks so their horizontal lines clear earlier drops.
        routes = []
        route_step = min(8, max(2, (x0 - 190) / 9))
        bottom = y0 + 20 * pitch + gap
        for port, owner in reverse_ports.items():
            px, _py, rect = port_geometry[port]
            sx, sy = fpc_centers[owner]
            bus_x = 152 + (owner - 1) * route_step
            lane = int(port[1]) - 1
            track_y = y0 - 56 - lane * 6 if port[0] == "T" else bottom + 52 + lane * 6
            end_y = rect[1] if port[0] == "T" else rect[3]
            points = (sx, sy, bus_x, sy, bus_x, track_y, px, track_y, px, end_y)
            routes.append((owner == fpc, owner, points))
        for active, owner, points in sorted(routes):
            if active:
                canvas.create_line(*points, fill="#f6f8fb", width=6, joinstyle="round")
            opacity = 0.8 if self.state.emphasize_connections.get() else 0.55
            options = {"width": 2.5, "fill": COLORS[owner - 1]} if active else {
                "width": 1.5, "fill": faded_color(COLORS[owner - 1], opacity)}
            canvas.create_line(*points, **options, joinstyle="round", arrow="last", arrowshape=(6, 8, 3),
                               tags=("connection", f"connection_fpc_{owner}",
                                     "selected_connection" if active else "faded_connection"))

        # All labels sit above the routes, even when every connection is visible.
        for port in PORTS:
            px, py, rect = port_geometry[port]
            owner = reverse_ports.get(port)
            canvas.create_rectangle(*rect, fill=COLORS[owner - 1] if owner else "#dce3ec", outline="#91a5bd")
            label = f"{port}←F{owner}" if owner else f"{'上端' if port[0] == 'T' else '下端'}{port[1]}"
            canvas.create_text(px, py, text=label,
                               fill="white" if owner else "#435870", font=("sans", 9))
            self.hit_ports.append((*rect, port))
        cells = {(entry["row"], entry["column"]): (key, entry) for key, entry in self.state.model.channels.items()}
        image = bytes.fromhex(self.state.app.latest["image"]) if self.state.app.latest else bytes(50)
        oe = self.state.app.connected and self.state.app.latest and self.state.app.latest["oe"]
        fast = oe and active_frequency(self.state.app.latest)
        if preview is None:
            focus = self.state.cell if self.state.cell and cell_port(*self.state.cell) == bound else None
        focus_row, focus_column = focus if focus else (None, None)
        crosshair = []
        if focus:
            cx = x0 + (focus_column - 1) * pitch
            cy = y0 + (focus_row - 1) * pitch + (gap if focus_row > 10 else 0)
            crosshair = [(x0, cy, x0 + 20 * pitch, cy + pitch),
                         (cx, y0, cx + pitch, y0 + 10 * pitch),
                         (cx, y0 + 10 * pitch + gap, cx + pitch, bottom)]
            for rect in crosshair:
                canvas.create_rectangle(*rect, fill="#dce7f1", outline="", tags="crosshair_background")
        for column in range(1, 21):
            cx = x0 + (column - 0.5) * pitch
            active_axis = column == focus_column
            if active_axis:
                canvas.create_rectangle(cx - pitch / 2 + .5, y0 - 19, cx + pitch / 2 - .5, y0 - 2,
                                        fill="#345b80", outline="")
            canvas.create_text(cx, y0 - 10, text=f"{column:02d}", fill="white" if active_axis else "#61738a",
                               font=("sans", 8, "bold") if active_axis else ("sans", 8),
                               tags=("selected_column_label",) if active_axis else ())
        for row in range(1, 21):
            y = y0 + (row - 1) * pitch + (gap if row > 10 else 0)
            active_axis = row == focus_row
            if active_axis:
                canvas.create_rectangle(x0 - 29, y + .5, x0 - 5, y + pitch - .5, fill="#345b80", outline="")
            canvas.create_text(x0 - 17, y + pitch / 2, text=f"{row:02d}", fill="white" if active_axis else "#61738a",
                               font=("sans", 8, "bold") if active_axis else ("sans", 8),
                               tags=("selected_row_label",) if active_axis else ())
            for column in range(1, 21):
                x = x0 + (column - 1) * pitch
                found = cells.get((row, column))
                fill, outline, text, ink = "#eef1f6", "#d3dce8", "·", "#a0acbc"
                if found:
                    key, entry = found
                    info = source(*key)
                    high = oe and image[info["chip"]] & (1 << info["bit"])
                    fill = "#279673" if high else ("#e4f0fa" if entry["verified"] else
                                                  ("#eae5f7" if entry["basis"] == "wiring" else "#fff0c2"))
                    outline, ink = COLORS[key[0] - 1], "white" if high else "#294059"
                    if fast:
                        fill, ink = "#e4d8fb", "#594078"
                    text = str(key[1])
                    if key[0] != fpc:
                        fill = faded_color(fill)
                        outline = faded_color(outline, 0.6)
                        ink = faded_color("#294059", 0.65)
                if preview is not None:
                    text = preview[row - 1][column - 1]
                    fill, ink = ("#279673", "white") if text == "1" else ("#f3f6fb", "#536579")
                selected = focus == (row, column)
                previous = preview is None and bool(found) and self.state.previous_cell == (row, column) and not selected
                if previous:
                    outline = faded_color("#152f51", 0.25)
                inset = 2 if selected else 1
                tags = ("cell_box", f"cell_box_r{row}_c{column}")
                if selected or previous:
                    tags += ("selected_cell" if selected else "previous_cell",)
                canvas.create_rectangle(x + inset, y + inset, x + pitch - inset, y + pitch - inset, fill=fill,
                                        outline="#152f51" if selected else outline,
                                        width=2 if selected else (1.5 if previous else 1), tags=tags)
                canvas.create_text(x + pitch / 2, y + pitch / 2, text=text, fill=ink, font=("sans", 8),
                                   tags=("cell_label", f"cell_r{row}_c{column}"))
        # Outline the row/column gutters instead of drawing through their numbers.
        for rect in crosshair:
            canvas.create_rectangle(*rect, outline="#7697b5", width=1, dash=(3, 3), tags="crosshair")
        for side in ("T", "B"):
            sy = y0 if side == "T" else y0 + pitch * 10 + gap
            for lane in range(5):
                port = f"{side}{lane + 1}"
                sx = x0 + lane * pitch * 4
                owner = reverse_ports.get(port)
                canvas.create_rectangle(sx, sy, sx + 4 * pitch, sy + 10 * pitch,
                                        outline=(COLORS[owner - 1] if owner == fpc else faded_color(COLORS[owner - 1], 0.6))
                                        if owner else "#7d91a9", width=3 if owner == fpc else 1)
        canvas.create_text(x0 + 10 * pitch, y0 + 10 * pitch + gap / 2, text="上半区 10行  /  下半区 10行", fill="#728398", font=("sans", 8))

    def hit_cell(self, x, y):
        if not hasattr(self, "grid_geometry"):
            return None
        x0, y0, pitch, gap = self.grid_geometry
        dx, dy = x - x0, y - y0
        if dx < 0 or dx >= 20 * pitch or dy < 0:
            return None
        if 10 * pitch <= dy < 10 * pitch + gap:
            return None
        if dy >= 10 * pitch + gap:
            dy -= gap
        if dy >= 20 * pitch:
            return None
        return int(dy // pitch) + 1, int(dx // pitch) + 1

