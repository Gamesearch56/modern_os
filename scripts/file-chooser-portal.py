#!/usr/bin/env python3
"""File chooser portal backend: other apps choose files in ModernOS Files.

xdg-desktop-portal hands OpenFile / SaveFile / SaveFiles requests from
Vivaldi, Firefox, Electron and Flatpak apps to the backend that
hyprland-portals.conf names. This one starts a Files window in chooser
mode (files-window.qml with MODERN_FILE_CHOOSE), waits for it to close,
and answers with what was chosen. A window closed without a choice
answers "cancelled".

The window writes {"paths": [...], "filter": n} to MODERN_FILE_CHOOSE_OUT;
a missing or unreadable answer is a cancel, never an error dialog.
"""

import glob
import json
import os
import subprocess
import sys
import tempfile

BUS_NAME = "org.freedesktop.impl.portal.desktop.modern"
OBJECT_PATH = "/org/freedesktop/portal/desktop"
IFACE = "org.freedesktop.impl.portal.FileChooser"
REQUEST_IFACE = "org.freedesktop.impl.portal.Request"

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib"))
from file_chooser_spec import (  # noqa: E402
    CANCELLED, ENDED, OK, answer_results, filter_globs, mime_globs, request_spec,
)

__all__ = ["CANCELLED", "ENDED", "OK", "answer_results", "filter_globs", "mime_globs", "request_spec"]


def session_env(base=None):
    """Activation may not carry the compositor variables; find them in the runtime dir."""
    env = dict(os.environ if base is None else base)
    runtime = env.get("XDG_RUNTIME_DIR") or "/run/user/%d" % os.getuid()
    if not env.get("WAYLAND_DISPLAY"):
        sockets = sorted(p for p in glob.glob(os.path.join(runtime, "wayland-*")) if not p.endswith(".lock"))
        if sockets:
            env["WAYLAND_DISPLAY"] = os.path.basename(sockets[0])
    if not env.get("HYPRLAND_INSTANCE_SIGNATURE"):
        dirs = sorted(glob.glob(os.path.join(runtime, "hypr", "*")), key=os.path.getmtime, reverse=True)
        if dirs:
            env["HYPRLAND_INSTANCE_SIGNATURE"] = os.path.basename(dirs[0])
    return env


def window_qml():
    home = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    return os.path.join(home, "quickshell", "modern", "files-window.qml")


def start_window(spec, out_path):
    env = session_env()
    # Paths.qml reads ~/.config/modern/repo asynchronously; the window lists
    # its folder before that lands, so it needs the repo up front.
    env.setdefault("MODERN_REPO", os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    env.update({
        "MODERN_FILE_WINDOW": "1",
        "MODERN_FILE_CHOOSE": json.dumps(spec),
        "MODERN_FILE_CHOOSE_OUT": out_path,
    })
    env.pop("MODERN_FILE_PATH", None)
    return subprocess.Popen(
        ["qs", "-p", window_qml()],
        env=env,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )


def read_answer(path):
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return None
    finally:
        try:
            os.unlink(path)
        except OSError:
            pass


RESULT_TYPES = {"uris": "as", "choices": "a(ss)", "current_filter": "(sa(us))"}

INTROSPECTION = """
<node>
  <interface name="%s">
    <method name="OpenFile">%s</method>
    <method name="SaveFile">%s</method>
    <method name="SaveFiles">%s</method>
    <property name="version" type="u" access="read"/>
  </interface>
  <interface name="%s">
    <method name="Close"/>
  </interface>
</node>
""" % ((IFACE,) + ("""
      <arg type="o" direction="in"/><arg type="s" direction="in"/>
      <arg type="s" direction="in"/><arg type="s" direction="in"/>
      <arg type="a{sv}" direction="in"/>
      <arg type="u" direction="out"/><arg type="a{sv}" direction="out"/>""",) * 3 + (REQUEST_IFACE,))


def serve():
    from gi.repository import Gio, GLib

    node = Gio.DBusNodeInfo.new_for_xml(INTROSPECTION)
    chooser_info, request_info = node.lookup_interface(IFACE), node.lookup_interface(REQUEST_IFACE)
    runtime = os.environ.get("XDG_RUNTIME_DIR") or tempfile.gettempdir()
    answers = os.path.join(runtime, "modern-file-chooser")
    os.makedirs(answers, mode=0o700, exist_ok=True)

    def reply(invocation, code, results):
        packed = {k: GLib.Variant(RESULT_TYPES[k], v) for k, v in results.items() if k in RESULT_TYPES}
        invocation.return_value(GLib.Variant("(ua{sv})", (code, packed)))

    def run(conn, method, handle, options, invocation):
        try:
            spec, raw = request_spec(method, options)
            fd, out_path = tempfile.mkstemp(prefix="answer-", suffix=".json", dir=answers)
            os.close(fd)
            os.unlink(out_path)
            proc = start_window(spec, out_path)
        except Exception as exc:  # noqa: BLE001 - every failure must still answer the portal
            print("file-chooser-portal: %s failed to start: %s" % (method, exc), file=sys.stderr)
            reply(invocation, ENDED, {})
            return
        state = {"closed": False}

        def on_request(_c, _s, _p, _i, _m, _a, close):
            state["closed"] = True
            try:
                os.killpg(proc.pid, 15)
            except OSError:
                pass
            close.return_value(None)

        try:
            reg = conn.register_object(handle, request_info, on_request, None, None)
        except GLib.Error:
            reg = 0

        def done(_pid, _status):
            answer = read_answer(out_path)
            if reg:
                conn.unregister_object(reg)
            code, results = ENDED, {}
            if not state["closed"]:
                try:
                    code, results = answer_results(method, answer, options, raw)
                except Exception as exc:  # noqa: BLE001 - the app is still waiting for a reply
                    print("file-chooser-portal: %s answer failed: %s" % (method, exc), file=sys.stderr)
            reply(invocation, code, results)

        GLib.child_watch_add(GLib.PRIORITY_DEFAULT, proc.pid, done)

    def on_call(conn, _sender, _path, _iface, method, params, invocation):
        handle, _app, _parent, _title, options = params.unpack()
        run(conn, method, handle, options, invocation)

    def on_get(_conn, _sender, _path, _iface, prop):
        return GLib.Variant("u", 4) if prop == "version" else None

    def on_bus(conn, _name):
        conn.register_object(OBJECT_PATH, chooser_info, on_call, on_get, None)

    loop = GLib.MainLoop()
    flags = Gio.BusNameOwnerFlags.ALLOW_REPLACEMENT | Gio.BusNameOwnerFlags.REPLACE
    Gio.bus_own_name(Gio.BusType.SESSION, BUS_NAME, flags, on_bus, None, lambda *_: loop.quit())
    loop.run()


if __name__ == "__main__":
    serve()
