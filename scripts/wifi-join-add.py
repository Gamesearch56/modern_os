#!/usr/bin/env python3
"""Add the Wi-Fi profile in a keyfile without putting the secret on argv.

`nmcli connection import type keyfile` asks for a VPN plugin named
keyfile and fails before the password is checked. libnm reads the same
file and sends the profile over D-Bus.
"""
from __future__ import annotations

import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 2:
        print("wifi-join-add: expected a keyfile path", file=sys.stderr)
        return 1
    path = Path(sys.argv[1])
    try:
        import gi

        gi.require_version("NM", "1.0")
        from gi.repository import GLib, NM
    except Exception as exc:
        print(f"wifi-join-add: {exc}", file=sys.stderr)
        return 1
    keyfile = GLib.KeyFile()
    try:
        keyfile.load_from_file(str(path), GLib.KeyFileFlags.NONE)
        profile = NM.keyfile_read(keyfile, str(path.parent), NM.KeyfileHandlerFlags.NONE, None)
    except Exception as exc:
        print(f"wifi-join-add: {exc}", file=sys.stderr)
        return 1
    if profile is None:
        print("wifi-join-add: keyfile was not a connection", file=sys.stderr)
        return 1
    client = NM.Client.new(None)
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
