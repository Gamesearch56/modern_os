// Bar task-manager popup open state. Notifications toggles this without
// importing Bar internals. `hostScreenName` keeps the popup on the bar
// that opened it (or the focused monitor from the control panel).
// One row per application; End task kills the process tree.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"
import "taskbarEntries.js" as Entries

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
        return Entries.build(
            wins,
            Tray.orphans(wins),
            function (it) { return Tray.pidsOf(it); },
            RunningApps.hidden(wins, Tray.items),
            function (hint) { return Apps.resolveIcon(hint); }
        );
    }

    readonly property int count: (root.entries || []).length

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
            // Foreground start when dead (not --background).
            const name = id.replace(/\.desktop$/i, "");
            if (name.length)
                Quickshell.execDetached([Paths.modernLaunch, name]);
            root._raiseAfter = id;
            raiseWait.restart();
            return;
        }
        const addr = String(entry.address || (entry.addresses && entry.addresses[0]) || "");
        Hypr.activateWindow(addr);
    }

    function close(entry: var) {
        if (!entry)
            return;
        if (entry.kind === "window") {
            const addrs = entry.addresses && entry.addresses.length
                ? entry.addresses
                : [String(entry.address || "")];
            let anyAutostart = false;
            for (let i = 0; i < addrs.length; i++) {
                const a = String(addrs[i] || "");
                if (!a.length)
                    continue;
                const t = Hypr.toplevelByAddress(a);
                if (t && Hypr.isAutostartWindow(t)) {
                    anyAutostart = true;
                    break;
                }
            }
            // A visible autostart app parks. One already on the background
            // workspace must close, or the row stays and nothing happens.
            if (anyAutostart && !entry.background) {
                for (let j = 0; j < addrs.length; j++) {
                    const a = String(addrs[j] || "");
                    if (a.length)
                        Hypr.closeWindow(a);
                }
                Hypr.refreshToplevels();
                return;
            }
            if (anyAutostart) {
                for (let j = 0; j < addrs.length; j++) {
                    const a = String(addrs[j] || "");
                    if (!a.length)
                        continue;
                    const id = Hypr.autostartIdOf(Hypr.toplevelByAddress(a));
                    if (id.length)
                        Hypr.suppressAutostartRespawn(id);
                    Hypr.dismissWindow(a);
                }
                Hypr.refreshToplevels();
                return;
            }
            RunningApps.killEntry(entry);
            for (let k = 0; k < addrs.length; k++) {
                const a = String(addrs[k] || "");
                if (a.length)
                    Hypr.killWindow(a);
            }
        } else {
            // A headless row is its own process. Parking every login app
            // here used to return before that process was killed.
            RunningApps.killEntry(entry);
            if (entry.kind === "tray")
                Tray.dismiss(entry.item);
        }
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
