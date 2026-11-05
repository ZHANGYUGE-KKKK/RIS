"""Optional Tk/Matplotlib window for local capture analysis; no board traffic."""
import queue
import threading
import tkinter as tk
from tkinter import filedialog, ttk

from rx706_spectrum import AnalysisCancelled, analyze_bin, display_trace


class SpectrumWindow:
    def __init__(self, parent, filename=""):
        # Lazy imports keep the board-control UI usable without plotting packages.
        from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg, NavigationToolbar2Tk
        from matplotlib.figure import Figure

        self.window = tk.Toplevel(parent)
        self.window.title("IQ FFT 频谱 · 本地 bin 文件")
        self.window.geometry("1080x780")
        self.window.minsize(960, 700)
        self.window.protocol("WM_DELETE_WINDOW", self.close)
        self.closed = self.busy = False
        self.events = queue.Queue()
        self.cancel = threading.Event()
        self.thread = None
        self.result = None
        self.poll_after = None
        self.filename = tk.StringVar(value=str(filename))
        self.channel = tk.StringVar(value="RX1")
        self.nfft = tk.StringVar(value="65536")
        self.averages = tk.StringVar(value="16")
        self.first_tuple = tk.StringVar(value="0")
        self.rate = tk.StringVar(value="15.36")
        self.remove_dc = tk.BooleanVar(value=True)
        self.auto = tk.BooleanVar(value=False)
        self.status = tk.StringVar(value="选择已下载的 bin，点击分析；无需连接板卡")
        self.summary = tk.StringVar(value="频率轴为 I+jQ 的有符号基带频率；0 Hz 为接收 LO。")
        self.controls = []
        outer = ttk.Frame(self.window, padding=12)
        outer.pack(fill="both", expand=True)
        path_row = ttk.Frame(outer)
        path_row.pack(fill="x")
        ttk.Label(path_row, text="IQ 文件").pack(side="left", padx=(0, 6))
        entry = ttk.Entry(path_row, textvariable=self.filename)
        entry.pack(side="left", fill="x", expand=True, padx=(0, 8))
        browse = ttk.Button(path_row, text="打开 bin…", command=self.browse)
        browse.pack(side="left")
        self.controls.extend((entry, browse))
        settings = ttk.Frame(outer)
        settings.pack(fill="x", pady=10)
        for label, variable, values, width in [
            ("通道", self.channel, ("RX1", "RX2"), 5),
            ("FFT 点数", self.nfft, tuple(str(1 << p) for p in range(8, 21)), 9),
            ("平均段数", self.averages, None, 5),
            ("起始点", self.first_tuple, None, 12),
            ("Fs(MSPS)", self.rate, None, 8),
        ]:
            ttk.Label(settings, text=label).pack(side="left", padx=(0, 5))
            widget = (ttk.Combobox(settings, textvariable=variable, values=values,
                                   state="readonly", width=width) if values else
                      ttk.Entry(settings, textvariable=variable, width=width))
            widget.pack(side="left", padx=(0, 12))
            self.controls.append(widget)
        actions = ttk.Frame(outer)
        actions.pack(fill="x")
        dc = ttk.Checkbutton(actions, text="去直流", variable=self.remove_dc)
        dc.pack(side="left", padx=(0, 12))
        self.controls.append(dc)
        ttk.Checkbutton(actions, text="新下载完成后自动分析", variable=self.auto).pack(side="left", padx=(0, 14))
        self.analyze_button = ttk.Button(actions, text="分析频谱", command=self.analyze)
        self.analyze_button.pack(side="left", padx=(0, 8))
        self.stop_button = ttk.Button(actions, text="停止分析", command=self.cancel.set, state="disabled")
        self.stop_button.pack(side="left")
        ttk.Label(outer, text="Hann 窗 / 非重叠分段功率平均 / 同名 JSON 的采样率优先；无 JSON 时使用上方 Fs。"
                  "短文件会自动减少 FFT 点数和平均段数。", wraplength=1020).pack(fill="x", pady=(8, 0))
        ttk.Label(outer, textvariable=self.status, wraplength=1020, foreground="#24486c").pack(fill="x", pady=(8, 2))
        ttk.Label(outer, textvariable=self.summary, wraplength=1020).pack(fill="x", pady=(0, 6))
        self.figure = Figure(figsize=(9, 4), dpi=100, layout="constrained")
        self.axes = self.figure.add_subplot(111)
        self._empty_axes()
        self.canvas = FigureCanvasTkAgg(self.figure, master=outer)
        # Pack toolbar before the expanding canvas to keep it visible on resize.
        self.toolbar = NavigationToolbar2Tk(self.canvas, outer, pack_toolbar=False)
        self.toolbar.pack(side="bottom", fill="x")
        self.canvas.get_tk_widget().pack(fill="both", expand=True)
        self.canvas.draw()
        self.poll_after = self.window.after(50, self.poll)

    def _empty_axes(self):
        self.axes.clear()
        self.axes.set_xlabel("Baseband frequency (MHz), I + jQ")
        self.axes.set_ylabel("Amplitude (dBFS / FFT bin)")
        self.axes.set_ylim(-140, 5)
        self.axes.grid(True, alpha=0.25)

    def browse(self):
        filename = filedialog.askopenfilename(parent=self.window, title="选择下载完成的 IQ bin 文件",
            filetypes=[("原始 IQ", "*.bin"), ("所有文件", "*")])
        if filename:
            self.filename.set(filename)

    def offer_download(self, filename):
        if not self.closed and not self.busy:
            self.filename.set(str(filename))
            if self.auto.get():
                self.analyze()

    def _buttons(self):
        for widget in self.controls:
            widget.configure(state="disabled" if self.busy else
                             ("readonly" if isinstance(widget, ttk.Combobox) else "normal"))
        self.analyze_button.configure(state="disabled" if self.busy else "normal")
        self.stop_button.configure(state="normal" if self.busy else "disabled")

    def analyze(self):
        if self.closed or self.busy:
            return
        try:
            name = self.filename.get().strip()
            if not name:
                raise ValueError("请选择已下载的 bin 文件")
            options = dict(channel=1 if self.channel.get() == "RX1" else 2,
                nfft=int(self.nfft.get()), averages=int(self.averages.get()),
                first_tuple=int(self.first_tuple.get()), sample_rate_hz=float(self.rate.get()) * 1e6,
                remove_dc=self.remove_dc.get())
        except ValueError as exc:
            self.status.set(f"参数错误：{exc}")
            return
        self.result = None
        self._empty_axes()
        self.axes.set_title("Analyzing local IQ file...")
        self.toolbar.update()
        self.canvas.draw()
        self.busy = True
        self.cancel.clear()
        self.status.set("正在分块读取和分析本地文件…")
        self.summary.set("")
        self._buttons()
        self.thread = threading.Thread(target=self._analyze_worker, args=(name, options),
                                       daemon=True, name="rx706-fft")
        self.thread.start()

    def _analyze_worker(self, name, options):
        try:
            result = analyze_bin(name, cancel_event=self.cancel, **options)
            # Prepare a bounded plot trace in the worker as well.
            self.events.put(("result", (result, display_trace(result))))
        except AnalysisCancelled as exc:
            self.events.put(("cancelled", str(exc)))
        except Exception as exc:
            self.events.put(("error", str(exc)))

    def poll(self):
        if self.closed:
            return
        try:
            kind, value = self.events.get_nowait()
        except queue.Empty:
            pass
        else:
            self.busy = False
            self._buttons()
            self._empty_axes()
            self.toolbar.update()
            if kind == "result":
                result, (freq, power) = value
                self.result = result
                self.rate.set(f"{result.sample_rate_hz / 1e6:g}")
                self.axes.plot(freq, power, color="#2467a4", linewidth=0.8)
                self.axes.set_xlim(-result.sample_rate_hz / 2e6, result.sample_rate_hz / 2e6)
                self.axes.set_ylim(max(-180, float(result.dbfs.max()) - 110), max(5, float(result.dbfs.max()) + 5))
                self.axes.set_title(f"RX{result.channel} | Hann | N={result.nfft:,} | averages={result.averages}")
                if result.peak_hz is not None:
                    self.axes.plot(result.peak_hz / 1e6, result.peak_dbfs, "o", color="#d15d32", markersize=5)
                    peak = f"主峰 {result.peak_hz / 1e6:+.6f} MHz / {result.peak_dbfs:.2f} dBFS"
                else:
                    peak = "所分析片段没有可显示的非零信号"
                self.status.set(f"RX{result.channel}：{peak}；复数 RMS {result.rms_counts:.2f} counts；"
                                f"削顶 {result.clipped:,}/{result.samples:,}")
                self.summary.set(f"Fs={result.sample_rate_hz / 1e6:g} MSPS（{result.rate_source}）；"
                    f"Δf={result.sample_rate_hz / result.nfft:.3f} Hz；"
                    f"分析点 [{result.first_tuple:,}, {result.first_tuple + result.samples:,}) / 共 {result.total_tuples:,} 点；"
                    f"时长 {result.samples / result.sample_rate_hz:.6g} s；去直流={'是' if result.remove_dc else '否'}。"
                    "幅度以 12 位复数满幅为参考，非 dBm。")
            else:
                self.axes.set_title("Analysis stopped" if kind == "cancelled" else "Analysis failed")
                self.status.set(("" if kind == "cancelled" else "分析失败：") + value)
            self.canvas.draw()
        self.poll_after = self.window.after(50, self.poll)

    def close(self):
        if self.closed:
            return
        self.closed = True
        self.cancel.set()
        if self.poll_after:
            self.window.after_cancel(self.poll_after)
            self.poll_after = None
        self.window.destroy()
