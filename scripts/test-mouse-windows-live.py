#!/usr/bin/env python3
"""Live check of the side-button window controls (modules/mouse_windows.lua).

Runs inside a Hyprland session. Opens a throwaway GTK window that logs the
buttons it receives, then drives a virtual uinput mouse against it.
Needs python-evdev, GTK 4 bindings and write access to /dev/uinput
(the input group). Not part of CI: it moves the real pointer.
"""
import json
import os
import subprocess
import sys
import tempfile
import time

from evdev import UInput, ecodes as e

APP_ID = "dev.modern.mousecheck"
PROBE = r'''
import sys, gi
gi.require_version("Gtk", "4.0")
from gi.repository import Gtk, Gdk
log = sys.argv[1]
NAMES = {Gdk.EventType.BUTTON_PRESS: "press", Gdk.EventType.BUTTON_RELEASE: "release"}
def put(s):
    with open(log, "a") as f:
        f.write(s + "\n")
def on_event(c, *a):
    ev = c.get_current_event()
    if ev is not None and ev.get_event_type() in NAMES:
        put(f"{NAMES[ev.get_event_type()]} {ev.get_button()}")
    return False
def act(app):
    w = Gtk.ApplicationWindow(application=app, title="mouse-check")
    w.set_default_size(700, 500)
    w.set_child(Gtk.Label(label="mouse check"))
    # Raw events: a click gesture drops presses that turn into drags.
    c = Gtk.EventControllerLegacy()
    c.set_propagation_phase(Gtk.PropagationPhase.CAPTURE)
    c.connect("event", on_event)
    w.add_controller(c)
    w.present()
app = Gtk.Application(application_id="APP_ID")
app.connect("activate", act)
app.run([])
'''.replace("APP_ID", APP_ID)

BTN = {"left": e.BTN_LEFT, "middle": e.BTN_MIDDLE, "side": e.BTN_SIDE, "extra": e.BTN_EXTRA}
failures = []


def hypr(*args):
    return subprocess.run(["hyprctl", *args], capture_output=True, text=True).stdout


def window():
    for c in json.loads(hypr("clients", "-j")):
        if c["class"] == APP_ID:
            return c
    return None


def check(name, ok, detail=""):
    print(("PASS " if ok else "FAIL ") + name + (f"  ({detail})" if detail else ""))
    if not ok:
        failures.append(name)


class Mouse:
    def __init__(self):
        # Without a wheel libinput turns middle drags into scrolling.
        cap = {e.EV_KEY: list(BTN.values()), e.EV_REL: [e.REL_X, e.REL_Y, e.REL_WHEEL]}
        self.ui = UInput(cap, name="modern-mouse-check")
        self.kb = UInput({e.EV_KEY: [e.KEY_LEFTMETA]}, name="modern-mouse-check-keys")
        time.sleep(1.0)

    def key(self, b, v):
        self.ui.write(e.EV_KEY, BTN[b], v)
        self.ui.syn()

    def move(self, dx, dy, steps=20):
        for _ in range(steps):
            self.ui.write(e.EV_REL, e.REL_X, dx // steps)
            self.ui.write(e.EV_REL, e.REL_Y, dy // steps)
            self.ui.syn()
            time.sleep(0.012)

    def click(self, b):
        self.key(b, 1); time.sleep(0.06); self.key(b, 0); time.sleep(0.6)

    def drag(self, b, dx, dy, hold=0.35):
        self.key(b, 1); time.sleep(hold); self.move(dx, dy); time.sleep(0.05)
        self.key(b, 0); time.sleep(0.6)

    def moving_click(self, b):
        # A real quick click while the hand is still travelling:
        # about 150 ms down and 120 px of motion.
        self.key(b, 1); self.move(100, 60, 10); time.sleep(0.03)
        self.key(b, 0); time.sleep(0.6)

    def jitter_click(self, b):
        self.key(b, 1); time.sleep(0.04); self.move(4, 3, 2); time.sleep(0.04)
        self.key(b, 0); time.sleep(0.6)

    def super_drag(self, dx, dy):
        self.kb.write(e.EV_KEY, e.KEY_LEFTMETA, 1); self.kb.syn(); time.sleep(0.05)
        self.drag("left", dx, dy)
        self.kb.write(e.EV_KEY, e.KEY_LEFTMETA, 0); self.kb.syn(); time.sleep(0.3)

    def chord(self, hold, b):
        self.key(hold, 1); time.sleep(0.08); self.click(b); self.key(hold, 0)
        time.sleep(0.6)


def focus_center(m):
    w = window()
    x, y = w["at"]; cw, ch = w["size"]
    hypr("eval", f"hl.dispatch(hl.dsp.cursor.move({{x={x + cw // 2},y={y + ch // 2}}}))")
    m.move(8, 8, 4)
    time.sleep(0.3)


def main():
    log = os.path.join(tempfile.mkdtemp(prefix="mouse-check-"), "events.log")
    open(log, "w").close()
    events = lambda: open(log).read().split("\n")[:-1]
    probe = subprocess.Popen([sys.executable, "-c", PROBE, log])
    try:
        for _ in range(50):
            if window():
                break
            time.sleep(0.1)
        check("probe window opened", window() is not None)
        if not window():
            return
        m = Mouse()

        focus_center(m); n = len(events()); m.click("side")
        check("back click reaches the app", events()[n:] == ["press 8", "release 8"], events()[n:])
        focus_center(m); n = len(events()); m.click("extra")
        check("forward click reaches the app", events()[n:] == ["press 9", "release 9"], events()[n:])
        focus_center(m); n = len(events()); m.click("left")
        check("left click untouched", events()[n:] == ["press 1", "release 1"], events()[n:])

        focus_center(m); n = len(events()); m.jitter_click("side")
        check("back click with a few pixels of jitter stays a click", events()[n:] == ["press 8", "release 8"], events()[n:])
        for b, num in (("side", 8), ("extra", 9)):
            focus_center(m); n = len(events()); before = (window()["at"], window()["size"])
            m.moving_click(b)
            check(f"quick {b} click while moving stays a click", events()[n:] == [f"press {num}", f"release {num}"], events()[n:])
            check(f"quick {b} click while moving leaves the window alone",
                  (window()["at"], window()["size"]) == before, f"{before} -> {(window()['at'], window()['size'])}")

        focus_center(m); n = len(events()); m.click("middle")
        check("middle click reaches the app", events()[n:] == ["press 2", "release 2"], events()[n:])
        focus_center(m); n = len(events()); before = window()["at"]
        m.drag("middle", 120, 80, hold=0.05)
        got = events()[n:]
        check("middle drag reaches the app", got == ["press 2", "release 2"] and window()["at"] == before, got)

        focus_center(m); n = len(events()); floating = window()["floating"]
        m.chord("side", "middle")
        check("back + middle toggles floating", window()["floating"] != floating)
        check("back + middle sends no button to the app", events()[n:] == [], events()[n:])
        focus_center(m); m.chord("side", "middle")
        check("back + middle toggles floating back", window()["floating"] == floating)

        focus_center(m); n = len(events()); m.chord("extra", "middle")
        check("forward + middle enters fullscreen", window()["fullscreen"] == 2, window()["fullscreen"])
        check("forward + middle sends no button to the app", events()[n:] == [], events()[n:])
        m.move(4, 4, 2); time.sleep(0.3); n = len(events())
        m.chord("extra", "middle")
        check("forward + middle leaves fullscreen", window()["fullscreen"] == 0, window()["fullscreen"])
        check("in fullscreen the forward button still reaches the app", "press 9" in events()[n:], events()[n:])

        # Floating, so a move is visible in "at" wherever tiling put it.
        if not window()["floating"]:
            hypr("dispatch", f"hl.dsp.window.float({{ action = 'toggle', window = 'address:{window()['address']}' }})")
        time.sleep(0.4)
        focus_center(m); before = window()["at"]
        m.super_drag(-200, -100)
        check("SUPER + left drag still moves the window", window()["at"] != before, f"{before} -> {window()['at']}")

        focus_center(m); n = len(events()); before = window()["at"]
        m.drag("side", -200, -100)
        check("hold back + move moves the window", window()["at"] != before, f"{before} -> {window()['at']}")
        check("move sends no button to the app", events()[n:] == [], events()[n:])

        focus_center(m); n = len(events()); before = window()["size"]
        m.drag("extra", 120, 90)
        check("hold forward + move resizes the window", window()["size"] != before, f"{before} -> {window()['size']}")
        check("resize sends no button to the app", events()[n:] == [], events()[n:])

        layers = [l for mon in json.loads(hypr("layers", "-j")).values()
                  for lv in ("2", "3") for l in mon["levels"].get(lv, []) if l["w"] > 0]
        if layers:
            l = layers[0]
            focus_center(m); n = len(events())
            hypr("eval", f"hl.dispatch(hl.dsp.cursor.move({{x={l['x'] + 5},y={l['y'] + l['h'] // 2}}}))")
            time.sleep(0.2); m.click("side")
            check("back click over the bar is not sent to the window", events()[n:] == [], events()[n:])

        focus_center(m)
        hypr("dispatch", f"hl.dsp.window.fullscreen({{ window = 'address:{window()['address']}' }})")
        time.sleep(0.8); m.move(4, 4, 2); time.sleep(0.3)
        n = len(events()); before = window()["at"]
        m.drag("side", 200, 100)
        got = events()[n:]
        check("fullscreen: back button goes to the app untouched", got[:1] == ["press 8"], got)
        hypr("dispatch", f"hl.dsp.window.fullscreen({{ window = 'address:{window()['address']}' }})")
        time.sleep(0.8)

        game = hypr("repl", 'return tostring(require("modules.game_match").is_game({class = "wow", title = "World of Warcraft"}))').strip()
        check("game windows are recognised", game == "true", game)

        focus_center(m); n = len(events()); m.chord("extra", "side")
        time.sleep(0.8)
        check("forward + back closes the window", window() is None)
        if window() is None:
            probe.wait(5)
            open(log, "w").close()
            probe = subprocess.Popen([sys.executable, "-c", PROBE, log])
            for _ in range(50):
                if window():
                    break
                time.sleep(0.1)

        focus_center(m); n = len(events()); m.chord("side", "extra")
        time.sleep(0.8)
        check("back + forward closes the window", window() is None)
        check("close sends no button to the app", not any("8" in x or "9" in x for x in events()[n:]), events()[n:])
        m.ui.close()
        m.kb.close()
    finally:
        if probe.poll() is None:
            probe.terminate()
    print(f"\n{len(failures)} failed" if failures else "\nall passed")
    sys.exit(1 if failures else 0)


main()
