#!/usr/bin/env python3
"""File chooser portal backend: request parsing, answers, and a D-Bus round trip.

The round trip runs the real backend on a private session bus with a stand-in
`qs` that answers like the Files window would. It is skipped where
PyGObject or dbus-run-session are missing (the CI runner).
"""
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "scripts/file-chooser-portal.py"
FAILED = False


def ok(msg):
    print("test-file-chooser: ok " + msg)


def check(cond, msg):
    global FAILED
    if cond:
        ok(msg)
    else:
        FAILED = True
        print("test-file-chooser: FAIL " + msg, file=sys.stderr)


spec = importlib.util.spec_from_file_location("portal", SCRIPT)
portal = importlib.util.module_from_spec(spec)
spec.loader.exec_module(portal)

with tempfile.TemporaryDirectory() as tmp:
    table = os.path.join(tmp, "globs2")
    Path(table).write_text("# comment\n50:image/png:*.png\n50:image/jpeg:*.jpg\n50:image/jpeg:*.jpeg\n50:text/plain:*.txt\n")
    check(portal.mime_globs("image/png", table) == ["*.png"], "a MIME type becomes its globs")
    check(portal.mime_globs("image/*", table) == ["*.png", "*.jpg", "*.jpeg"], "image/* becomes every image glob")
    check(portal.filter_globs([(0, "*.pdf"), (1, "text/plain")], table) == ["*.pdf", "*.txt"], "glob and MIME rules mix in one filter")
    check(portal.filter_globs([(1, "application/x-unknown-to-everyone")], table) == ["*"], "a filter with no known glob shows every file")

    opts = {
        "filters": [("Images", [(1, "image/*")]), ("All files", [(0, "*")])],
        "current_filter": ("All files", [(0, "*")]),
        "multiple": True,
        "current_folder": list(b"/tmp\0"),
    }
    s, raw = portal.request_spec("OpenFile", opts, table)
    check(s["mode"] == "open" and s["multiple"] and s["folder"] == "/tmp", "open keeps multiple and the start folder")
    check([f["name"] for f in s["filters"]] == ["Images", "All files"] and s["filter"] == 1, "filters keep their names and the current one")
    check(portal.request_spec("OpenFile", {"directory": True, "multiple": True}, table)[0]["mode"] == "folder", "a directory request chooses a folder")
    check(not portal.request_spec("OpenFile", {"directory": True, "multiple": True}, table)[0]["multiple"], "a folder is always one folder")
    save = portal.request_spec("SaveFile", {"current_file": list(b"/home/u/a b.txt\0")}, table)[0]
    check(save["mode"] == "save" and save["folder"] == "/home/u" and save["name"] == "a b.txt", "save starts at the current file")
    check(portal.request_spec("SaveFile", {"current_name": "../x"}, table)[0]["name"] == "", "a suggested name with a slash is dropped")
    check(portal.request_spec("OpenFile", {"current_folder": list(b"relative\0")}, table)[0]["folder"] == "", "a relative start folder is dropped")

    code, res = portal.answer_results("OpenFile", {"paths": ["/tmp/a b.png", "relative"], "filter": 0}, opts, raw)
    check(code == 0 and res["uris"] == ["file:///tmp/a%20b.png"], "answers are file URIs; relative paths are dropped")
    check(res["current_filter"] == raw[0], "the filter in use is handed back")
    check(portal.answer_results("OpenFile", None, opts, raw) == (1, {}), "no answer is a cancel")
    check(portal.answer_results("OpenFile", {"paths": []}, opts, raw) == (1, {}), "an empty answer is a cancel")
    many = portal.answer_results("SaveFiles", {"paths": ["/out"]}, {"files": [list(b"one.txt\0"), list(b"../up\0"), list(b"two.txt\0")]}, [])
    check(many[1].get("uris") == ["file:///out/one.txt", "file:///out/two.txt"], "save-many joins names to the folder and drops escapes")
    picked = portal.answer_results("OpenFile", {"paths": ["/x"]}, {"choices": [("enc", "Encoding", [("u", "UTF-8")], "u")]}, [])
    check(picked[1].get("choices") == [("enc", "u")], "app choices are answered with their defaults")

    runtime = os.path.join(tmp, "run")
    os.makedirs(os.path.join(runtime, "hypr", "abc"))
    Path(runtime, "wayland-1").touch()
    Path(runtime, "wayland-1.lock").touch()
    env = portal.session_env({"XDG_RUNTIME_DIR": runtime})
    check(env.get("WAYLAND_DISPLAY") == "wayland-1" and env.get("HYPRLAND_INSTANCE_SIGNATURE") == "abc", "missing compositor variables are found in the runtime dir")


def deps():
    try:
        from gi.repository import Gio  # noqa: F401
    except ImportError:
        return False
    return bool(shutil.which("dbus-run-session") and shutil.which("gdbus"))


ROUND_TRIP = r'''
import json, subprocess, sys, time
from gi.repository import Gio, GLib
script, answer_mode = sys.argv[1], sys.argv[2]
name = "org.freedesktop.impl.portal.desktop.modern"
backend = subprocess.Popen([sys.executable, script])
bus = Gio.bus_get_sync(Gio.BusType.SESSION)
def owned():
    reply = bus.call_sync("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "NameHasOwner",
                          GLib.Variant("(s)", (name,)), None, 0, -1, None)
    return reply.unpack()[0]
for _ in range(100):
    if owned():
        break
    time.sleep(0.05)
handle = "/org/freedesktop/portal/desktop/request/1_1/t"
if answer_mode == "hang":
    subprocess.Popen(["sh", "-c", "sleep 1; gdbus call --session --dest %s "
                      "--object-path %s --method org.freedesktop.impl.portal.Request.Close >/dev/null" % (name, handle)])
opts = {"multiple": GLib.Variant("b", True),
        "current_folder": GLib.Variant("ay", b"/tmp/start dir\0"),
        "filters": GLib.Variant("a(sa(us))", [("Text", [(0, "*.txt")])])}
args = GLib.Variant("(osssa{sv})", (handle, "app", "", "Open", opts))
code, res = bus.call_sync(name, "/org/freedesktop/portal/desktop", "org.freedesktop.impl.portal.FileChooser",
                          "OpenFile", args, GLib.VariantType("(ua{sv})"), 0, 20000, None).unpack()
print(json.dumps({"code": code, "uris": res.get("uris", []),
                  "filter": res["current_filter"][0] if "current_filter" in res else ""}))
backend.terminate()
'''

FAKE_QS = r'''#!/usr/bin/env python3
import json, os, sys, time
spec = json.loads(os.environ["MODERN_FILE_CHOOSE"])
out = os.environ["MODERN_FILE_CHOOSE_OUT"]
with open(os.environ["FAKE_LOG"], "w") as fh:
    json.dump({"argv": sys.argv[1:], "spec": spec, "window": os.environ.get("MODERN_FILE_WINDOW"),
               "repo": os.environ.get("MODERN_REPO")}, fh)
mode = os.environ["FAKE_ANSWER"]
if mode == "hang":
    time.sleep(30)
elif mode == "pick":
    with open(out, "w") as fh:
        json.dump({"paths": ["/tmp/one.txt", "/tmp/two.txt"], "filter": 0}, fh)
'''


def round_trip(mode):
    with tempfile.TemporaryDirectory() as tmp:
        bindir = os.path.join(tmp, "bin")
        os.makedirs(bindir)
        qs = os.path.join(bindir, "qs")
        Path(qs).write_text(FAKE_QS)
        os.chmod(qs, 0o755)
        env = dict(os.environ, PATH=bindir + os.pathsep + os.environ["PATH"], FAKE_ANSWER=mode,
                   FAKE_LOG=os.path.join(tmp, "log.json"), XDG_CONFIG_HOME=os.path.join(tmp, "cfg"),
                   XDG_RUNTIME_DIR=tmp)
        env.pop("MODERN_REPO", None)
        out = subprocess.run(["dbus-run-session", "--", sys.executable, "-c", ROUND_TRIP, str(SCRIPT), mode],
                             env=env, capture_output=True, text=True, timeout=60)
        log = json.loads(Path(tmp, "log.json").read_text()) if Path(tmp, "log.json").exists() else {}
        left = os.listdir(os.path.join(tmp, "modern-file-chooser")) if os.path.isdir(os.path.join(tmp, "modern-file-chooser")) else []
        try:
            return json.loads(out.stdout.strip().splitlines()[-1]), log, left
        except (IndexError, ValueError):
            print(out.stderr, file=sys.stderr)
            return {}, log, left


if deps():
    got, log, left = round_trip("pick")
    check(got.get("code") == 0 and got.get("uris") == ["file:///tmp/one.txt", "file:///tmp/two.txt"], "a choice in the window reaches the app")
    check(got.get("filter") == "Text", "the app learns which filter was used")
    check(log.get("argv", [""])[-1].endswith("quickshell/modern/files-window.qml") and log.get("window") == "1", "the chooser is a Files window")
    check(log.get("spec", {}).get("folder") == "/tmp/start dir", "the start folder survives the bus")
    check(log.get("repo") == str(ROOT), "the window knows the repo before its first listing")
    check(log.get("spec", {}).get("multiple") is True and log.get("spec", {}).get("filters") == [{"name": "Text", "patterns": ["*.txt"]}], "the window gets the request")
    check(left == [], "no answer file is left behind")
    got, _, _ = round_trip("cancel")
    check(got.get("code") == 1 and got.get("uris") == [], "closing the window cancels")
    got, _, _ = round_trip("hang")
    check(got.get("code") == 2, "the app closing the request ends the window")
else:
    ok("PyGObject or dbus-run-session missing; round trip skipped")

sys.exit(1 if FAILED else 0)
