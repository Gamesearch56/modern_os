// Bar task-manager popup open state. Notifications toggles this without
// importing Bar internals. `hostScreenName` keeps the popup on the bar
// that opened it (or the focused monitor from the control panel).
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property bool open: false
    property bool coverFullscreen: false
    property string hostScreenName: ""

    readonly property var entries: {
        void Hypr.toplevelList;
        void Tray.items;
        void RunningApps.apps;
        const wins = Hypr.toplevelList || [];
        const out = [];
        for (let i = 0; i < wins.length; i++) {
            const t = wins[i];
            if (!t)
                continue;
            const ipc = t.lastIpcObject || ({});
            const cls = String(ipc.class || t.class || "").toLowerCase();
            if (cls.indexOf("quickshell") !== -1)
                continue;
            const wsId = t.workspace ? Number(t.workspace.id) : 0;
            const hidden = !!(ipc.hidden === true || ipc.mapped === false);
            out.push({
                kind: "window",
                address: String(t.address || ipc.address || ""),
                title: String(t.title || ipc.class || cls),
                cls: String(ipc.class || t.class || "application-x-executable"),
                icon: Apps.resolveIcon(String(ipc.class || t.class || ipc.initialClass || "")),
                iconUrl: "",
                wsId: wsId,
                background: wsId < 0 || hidden,
                activated: t.activated === true,
                item: null,
                desktopId: "",
                pid: Number(ipc.pid || 0),
                pids: []
            });
        }
        const bg = Tray.orphans(wins);
        for (let j = 0; j < bg.length; j++) {
            const it = bg[j];
            const pids = Tray.pidsOf(it);
            if (!pids.length)
                continue;
            const title = String(it.title || it.tooltipTitle || it.id || "");
            out.push({
                kind: "tray",
                address: "",
                title: title,
                cls: title,
                icon: "",
                iconUrl: String(it.icon || ""),
                wsId: 0,
                background: true,
                activated: false,
                item: it,
                desktopId: "",
                pid: 0,
                pids: pids
            });
        }
        const procs = RunningApps.hidden(wins, Tray.items);
        for (let k = 0; k < procs.length; k++) {
            const app = procs[k];
            const pids = app.pids || [];
            if (!pids.length)
                continue;
            out.push({
                kind: "process",
                address: "",
                title: String(app.name || app.id || ""),
                cls: String(app.icon || app.class || app.id || ""),
                icon: Apps.resolveIcon(String(app.icon || app.class || app.id || "")),
                iconUrl: "",
                wsId: 0,
                background: true,
                activated: false,
                item: null,
                desktopId: String(app.id || ""),
                pid: 0,
                pids: app.pids || []
            });
        }
        return out;
    }

    readonly property int count: {
        void root.entries;
        return (root.entries || []).length;
    }

    property string _raiseAfter: ""

    Timer {
        id: raiseWait
        interval: 500
        repeat: false
        onTriggered: {
            const id = root._raiseAfter;
            root._raiseAfter = "";
            if (!id.length)
                return;
            Hypr.refreshToplevels();
            Hypr.raiseDesktop(id);
        }
    }

    Timer {
        interval: 1500
        running: root.open
        repeat: true
        onTriggered: RunningApps.refresh()
    }

    IpcHandler {
        target: "taskbar"
        function toggle() { root.toggle(null); }
        function show() { root.show(null); }
        function hide() { root.hide(); }
    }

    function toggle(screen: var) {
        const name = root._nameOf(screen) || root._focusedName();
        if (root.open && root.hostScreenName === name) {
            root.hide();
            return;
        }
        Hypr.refreshToplevels();
        RunningApps.refresh();
        root.hostScreenName = name;
        root.coverFullscreen = Hypr.focusedFullscreen;
        root.open = true;
    }

    function show(screen: var) {
        Hypr.refreshToplevels();
        RunningApps.refresh();
        root.hostScreenName = root._nameOf(screen) || root._focusedName();
        root.coverFullscreen = Hypr.focusedFullscreen;
        root.open = true;
    }

    function hide() {
        root.open = false;
        root.hostScreenName = "";
        root.coverFullscreen = false;
    }

    function activate(entry: var) {
        if (!entry)
            return;
        if (entry.kind === "tray") {
            Tray.activate(entry.item);
            return;
        }
        if (entry.kind === "process") {
            const id = String(entry.desktopId || "");
            if (Hypr.raiseDesktop(id))
                return;
            Apps.launchId(id);
            root._raiseAfter = id;
            raiseWait.restart();
            return;
        }
        Hypr.activateWindow(String(entry.address || ""));
    }

    function close(entry: var) {
        if (!entry)
            return;
        RunningApps.killEntry(entry);
        if (entry.kind === "window")
            Hypr.killWindow(String(entry.address || ""));
        if (entry.kind === "tray")
            Tray.dismiss(entry.item);
        Hypr.refreshToplevels();
        RunningApps.refresh();
    }

    function openOn(screen: var): bool {
        if (!root.open)
            return false;
        if (!root.hostScreenName)
            return true;
        const name = root._nameOf(screen);
        if (name && name === root.hostScreenName)
            return true;
        const mon = Hypr.monitorForScreen(screen);
        if (mon && String(mon.name) === root.hostScreenName)
            return true;
        return false;
    }

    function _nameOf(screen: var): string {
        if (screen && screen.name)
            return String(screen.name);
        return "";
    }

    function _focusedName(): string {
        const n = Hypr.focusedMonitorName();
        if (n && n.length)
            return n;
        const list = Quickshell.screens;
        if (list && list.length > 0 && list[0].name)
            return String(list[0].name);
        return "";
    }
}
