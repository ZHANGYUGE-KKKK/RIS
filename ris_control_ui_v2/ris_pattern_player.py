"""Acknowledgment-paced software playlist player, sharing the GUI TCP worker."""
from ris_frequency import active_frequency
import random

from ris_patterns import MODES, dwell_ms


class PatternPlayer:
    def __init__(self, scheduler, send, connected, busy, notify):
        self.scheduler, self.send = scheduler, send
        self.connected, self.busy, self.notify = connected, busy, notify
        self.active = False
        self.timer = None
        self.generation = 0
        self.index = 0
        self.direction = 1
        self.steps = []
        self.confirmed_index = None

    def start(self, steps, mode):
        if not steps or mode not in MODES:
            raise ValueError("请添加播放项并选择有效模式")
        if not self.connected() or self.busy():
            raise ValueError("请先连接板卡，并等待当前命令结束")
        snapshot = []
        for step in steps:
            if len(step["image"]) != 50:
                raise ValueError("图案长度应为50字节")
            snapshot.append({"name": step["name"], "image": bytes(step["image"]),
                             "dwell_ms": dwell_ms(step["dwell_ms"])})
        self.stop(notify=False)
        self.steps, self.mode = snapshot, mode
        self.index, self.direction, self.active = 0, 1, True
        self.confirmed_index = None
        self._issue(self.generation)

    def _schedule(self, duration, action):
        self.timer = self.scheduler.after(duration, action)

    def _issue(self, generation):
        self.timer = None
        if not self.active or generation != self.generation:
            return
        if not self.connected():
            self.stop("连接已断开，播放停止")
            return
        if self.busy():
            self._schedule(20, lambda: self._issue(generation))
            return
        index, step = self.index, self.steps[self.index]
        command = "FRAME " + step["image"].hex().upper()
        self.notify("sending", index, step["name"])

        def completed(reply, error):
            if not self.active or generation != self.generation:
                return  # Stop during an in-flight command must never schedule another.
            if error or not reply or not reply["ok"] or reply["errors"] or not reply["oe"] or reply["blink_ms"] or active_frequency(reply) or reply["image"].upper() != command.split()[1]:
                self.stop("图案下发未确认，播放停止；请检查连接和板端状态")
                return
            self.confirmed_index = index
            self.notify("holding", index, step["name"])
            self._schedule(step["dwell_ms"], lambda: self._advance(generation))

        if not self.send(command, completed):
            self.stop("命令未能提交，播放停止")

    def _advance(self, generation):
        self.timer = None
        if not self.active or generation != self.generation:
            return
        count = len(self.steps)
        if self.mode == "once" and self.index == count - 1:
            self.stop("顺序播放完成，保持最后图案")
            return
        if self.mode == "random":
            self.index = random.choice([i for i in range(count) if i != self.index]) if count > 1 else 0
        elif self.mode == "pingpong" and count > 1:
            if not 0 <= self.index + self.direction < count:
                self.direction *= -1
            self.index += self.direction
        else:
            self.index = (self.index + 1) % count
        self._issue(generation)

    def stop(self, reason="已停止，保持最后已下发图案", notify=True):
        was_active = self.active
        self.active = False
        self.generation += 1
        if self.timer is not None:
            self.scheduler.after_cancel(self.timer)
            self.timer = None
        if notify and was_active:
            self.notify("stopped", self.index, reason)
