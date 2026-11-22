#!/usr/bin/env python3
"""The issue a report opens names the device, and serials never leave.

device.txt becomes a Device section only when the user left it ticked;
monitor and disk serials are redacted in text and JSON alike.
"""
import importlib.util
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FAIL = 0


def check(cond, what):
    global FAIL
    print("test-report-device: %s %s" % ("ok" if cond else "FAIL", what))
    FAIL |= not cond


spec = importlib.util.spec_from_file_location("report_send", os.path.join(ROOT, "scripts/lib/report-send.py"))
send = importlib.util.module_from_spec(spec)
spec.loader.exec_module(send)

with tempfile.TemporaryDirectory() as tmp:
    files = os.path.join(tmp, "files")
    os.makedirs(files)
    with open(os.path.join(files, "device.txt"), "w", encoding="utf-8") as fh:
        fh.write("machine: Framework Laptop 13\ncpu: AMD Ryzen 7 7840U (16 threads)\n"
                 "gpu: Radeon 780M (driver amdgpu)\ngpu: GeForce RTX 4060 (driver nvidia)\n"
                 "display: BOE NE135A1M 2880x1920@120Hz scale 2\nvirtualization: \n")
    with open(os.path.join(files, "system.txt"), "w", encoding="utf-8") as fh:
        fh.write("version: v1.2.3\nkernel: 6.12.1-zen1\nlang: de_DE.UTF-8\n")
    req = {"title": "t", "description": "steps", "files": ["device.txt", "system.txt"]}
    body = send.issue_body(tmp, req, "v1.2.3", "https://example.org/r.tar.xz", [])
    check("## Device" in body and "**Machine:** `Framework Laptop 13`" in body, "the issue has a Device section")
    check(body.count("**GPU:**") == 2, "both graphics cards are listed")
    check("**Display:** `BOE NE135A1M 2880x1920@120Hz scale 2`" in body, "displays carry resolution, rate and scale")
    check("Virtualization" not in body, "an empty fact is left out")
    check("**Language:** `de_DE.UTF-8`" in body, "the environment names the language")
    check(body.index("## Environment") < body.index("## Device"), "Device follows Environment")
    req["files"] = ["system.txt"]
    check("## Device" not in send.issue_body(tmp, req, "v1.2.3", "u", []), "an unticked device.txt stays out")

    red = os.path.join(tmp, "red")
    os.makedirs(red)
    with open(os.path.join(red, "hyprland.txt"), "w", encoding="utf-8") as fh:
        fh.write('$ hyprctl monitors -j\n[{"name": "DP-1", "serial": "ABC123XYZ", "model": "AW2725DF"}]\n'
                 "Serial Number: S4EWNX0R123456\n")
    with open(os.path.join(red, "config.json"), "w", encoding="utf-8") as fh:
        json.dump({"monitors": [{"serial": "ABC123XYZ", "scale": 1}]}, fh)
    subprocess.run([sys.executable, os.path.join(ROOT, "scripts/lib/report-redact.py"), red], check=True)
    text = open(os.path.join(red, "hyprland.txt"), encoding="utf-8").read()
    conf = open(os.path.join(red, "config.json"), encoding="utf-8").read()
    check("ABC123XYZ" not in text and "S4EWNX0R123456" not in text and "AW2725DF" in text,
          "monitor and disk serials are redacted, the model stays")
    check("ABC123XYZ" not in conf and '"scale": 1' in conf, "a serial in JSON is redacted by key")

sys.exit(FAIL)
