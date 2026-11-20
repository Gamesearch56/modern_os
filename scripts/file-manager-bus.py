#!/usr/bin/env python3
"""Own org.freedesktop.FileManager1 and open those folders in ModernOS.

Browsers ask this bus name to show a download. The system service file
starts Nautilus; a session file in front of it starts this instead.
"""

import os
import subprocess
import urllib.parse

IFACE = "org.freedesktop.FileManager1"
PATH = "/org/freedesktop/FileManager1"


def local_path(uri):
    raw = str(uri or "").strip()
    if not raw or "\0" in raw:
        return ""
    if raw.startswith("file:"):
        parsed = urllib.parse.urlparse(raw)
        raw = urllib.parse.unquote(parsed.path or "")
    if not raw.startswith("/"):
        return ""
    parts = []
    for part in raw.split("/"):
        if part in ("", "."):
            continue
        if part == "..":
            return ""
        parts.append(part)
    return "/" + "/".join(parts) if parts else "/"


def launch(path, select):
    verb = "reveal" if select else "open"
    subprocess.Popen(
        ["qs", "-c", "modern", "ipc", "call", "files", verb, path],
        start_new_session=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def _first(uris, select):
    for uri in uris or []:
        path = local_path(uri)
        if path:
            launch(path, select or os.path.isfile(path))
            return


def serve():
    import dbus
    import dbus.mainloop.glib
    import dbus.service
    from gi.repository import GLib

    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()

    class FileManager(dbus.service.Object):
        def __init__(self):
            super().__init__(bus, PATH)

        @dbus.service.method(IFACE, in_signature="ass", out_signature="")
        def ShowItems(self, uris, startup_id):
            _first(uris, True)

        @dbus.service.method(IFACE, in_signature="ass", out_signature="")
        def ShowFolders(self, uris, startup_id):
            _first(uris, False)

        @dbus.service.method(IFACE, in_signature="ass", out_signature="")
        def ShowItemProperties(self, uris, startup_id):
            _first(uris, True)

    loop = GLib.MainLoop()
    owned = {"yes": False}

    def _acquired(name):
        if str(name) == IFACE:
            owned["yes"] = True

    def _lost(name):
        # A later shell reload replaces this owner. Leave instead of
        # stacking a process that no longer answers the bus name.
        if str(name) == IFACE and owned["yes"]:
            loop.quit()

    bus.add_signal_receiver(
        _acquired,
        signal_name="NameAcquired",
        dbus_interface="org.freedesktop.DBus",
        path="/org/freedesktop/DBus",
    )
    bus.add_signal_receiver(
        _lost,
        signal_name="NameLost",
        dbus_interface="org.freedesktop.DBus",
        path="/org/freedesktop/DBus",
    )
    owner = dbus.service.BusName(
        IFACE,
        bus,
        allow_replacement=True,
        replace_existing=True,
        do_not_queue=False,
    )
    service = FileManager()
    loop.run()
    return owner, service


if __name__ == "__main__":
    serve()
