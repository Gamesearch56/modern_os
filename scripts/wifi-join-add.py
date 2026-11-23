#!/usr/bin/env python3
"""Add a Wi-Fi profile from a keyfile and, when asked, bring that network up.

`nmcli connection import type keyfile` asks for a VPN plugin named
keyfile and fails before the password is checked. libnm reads the same
file. Activating against the access point from the scan lets
NetworkManager fill in the details a hand-written profile gets wrong,
which is why a correct password never associated.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

# NMDeviceStateReason values that mean the password was rejected.
_BAD_KEY = {7, 8, 9, 10}
_TIMEOUT = {11}
_MISSING = {53}


def _ssid_text(obj) -> str:
    raw = obj.get_ssid() if obj is not None else None
    if raw is None:
        return ""
    return bytes(raw.get_data()).decode("utf-8", "replace")


def _load_profile(path: Path):
    import gi

    gi.require_version("NM", "1.0")
    gi.require_version("GLib", "2.0")
    from gi.repository import GLib, NM

    keyfile = GLib.KeyFile()
    keyfile.load_from_file(str(path), GLib.KeyFileFlags.NONE)
    profile = NM.keyfile_read(keyfile, str(path.parent), NM.KeyfileHandlerFlags.NONE, None)
    if profile is None:
        raise RuntimeError("keyfile was not a connection")
    return GLib, NM, profile


def _best_ap(client, NM, ssid: str):
    chosen_device = None
    chosen_ap = None
    strength = -1
    for device in client.get_devices():
        if device.get_device_type() != NM.DeviceType.WIFI:
            continue
        for ap in device.get_access_points():
            if _ssid_text(ap) != ssid:
                continue
            rank = int(ap.get_strength())
            if rank > strength:
                strength = rank
                chosen_device = device
                chosen_ap = ap
    return chosen_device, chosen_ap


def _failure_code(reason: int) -> int:
    if reason in _BAD_KEY:
        return 3
    if reason in _TIMEOUT:
        return 5
    if reason in _MISSING:
        return 4
    return 1


def _activate(client, GLib, NM, profile) -> int:
    ssid = _ssid_text(profile.get_setting_wireless())
    device, ap = _best_ap(client, NM, ssid)
    if device is None or ap is None:
        print(f"wifi-join-add: {ssid} is not in the scan", file=sys.stderr)
        return 4
    loop = GLib.MainLoop()
    holder: dict[str, object] = {"code": 1, "arm": False}

    def finish(code: int, detail: str = "") -> None:
        if holder.get("settled"):
            return
        holder["settled"] = True
        holder["code"] = code
        if detail:
            print(f"wifi-join-add: {detail}", file=sys.stderr)
        loop.quit()

    def on_device(_device, new_state, _old_state, reason) -> None:
        if not holder.get("arm"):
            return
        state = int(new_state)
        why = int(reason)
        if state == int(NM.DeviceState.ACTIVATED):
            finish(0)
        elif state == int(NM.DeviceState.FAILED):
            finish(_failure_code(why), f"device failed reason {why}")

    def started(source, result, _data) -> None:
        try:
            active = source.add_and_activate_connection_finish(result)
        except Exception as exc:
            finish(1, str(exc))
            return
        holder["arm"] = True
        if active is not None and int(active.get_state()) == int(NM.ActiveConnectionState.ACTIVATED):
            finish(0)

    device.connect("state-changed", on_device)
    GLib.timeout_add_seconds(25, lambda: finish(5, "timed out") or False)
    client.add_and_activate_connection_async(profile, device, ap.get_path(), None, started, None)
    loop.run()
    code = int(holder["code"])
    if code == 0:
        print("activated")
    return code


def main() -> int:
    if len(sys.argv) != 2:
        print("wifi-join-add: expected a keyfile path", file=sys.stderr)
        return 1
    path = Path(sys.argv[1])
    try:
        GLib, NM, profile = _load_profile(path)
    except Exception as exc:
        print(f"wifi-join-add: {exc}", file=sys.stderr)
        return 1
    client = NM.Client.new(None)
    if os.environ.get("WIFI_JOIN_ACTIVATE") == "1":
        return _activate(client, GLib, NM, profile)
    loop = GLib.MainLoop()
    holder: dict[str, object] = {}

    def done(source, result, _data) -> None:
        try:
            holder["conn"] = source.add_connection_finish(result)
        except Exception as exc:
            holder["err"] = exc
        loop.quit()

    client.add_connection_async(profile, True, None, done, None)
    loop.run()
    if "err" in holder:
        print(f"wifi-join-add: {holder['err']}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
