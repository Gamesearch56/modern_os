// Hyprland IPC singleton. The only place the shell talks to Hyprland —
// workspaces, clients, monitors, dispatch. Modules never call hyprctl.
pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property bool hyprbarsLoaded: false

    readonly property var monitors: Hyprland.monitors
    readonly property var workspaces: Hyprland.workspaces
    readonly property var toplevels: Hyprland.toplevels
    readonly property var focusedWorkspace: Hyprland.focusedWorkspace
    readonly property var focusedToplevel: Hyprland.focusedToplevel

    function dispatch(cmd: string) {
        try {
            Hyprland.dispatch(cmd);
        } catch (e) {
            Logger.error("Hypr", "dispatch '" + cmd + "' failed: " + e);
        }
    }

    function focusWorkspace(id: int) {
        root.dispatch("workspace " + id);
    }

    function moveToWorkspace(id: int) {
        root.dispatch("movetoworkspace " + id);
    }

    function focusWindow(address: string) {
        root.dispatch("focuswindow address:" + address);
    }

    function closeWindow(address: string) {
        root.dispatch("closewindow address:" + address);
    }

    function reload() {
        root.dispatch("reload");
    }

    function monitorForScreen(screen: var): var {
        if (!screen)
            return null;
        const list = Hyprland.monitors?.values ?? Hyprland.monitors ?? [];
        for (let i = 0; i < list.length; i++) {
            const m = list[i];
            if (!m)
                continue;
            if (m.name && screen.name && m.name === screen.name)
                return m;
            if (m.description && screen.name && String(m.description).indexOf(screen.name) !== -1)
                return m;
        }
        return null;
    }

    function _sortedMonitors(): var {
        const list = Hyprland.monitors?.values ?? [];
        const out = [];
        for (let i = 0; i < list.length; i++)
            out.push(list[i]);
        out.sort((a, b) => (a.x ?? 0) - (b.x ?? 0));
        return out;
    }

    function reservedRange(screen: var): var {
        const mon = root.monitorForScreen(screen);
        if (!mon)
            return null;
        const mons = root._sortedMonitors();
        let idx = -1;
        for (let i = 0; i < mons.length; i++) {
            if (mons[i].name === mon.name)
                idx = i;
        }
        if (idx === 0)
            return ({ from: 1, to: 5 });
        if (idx === 1)
            return ({ from: 6, to: 10 });
        return null;
    }

    function workspacesFor(screen: var): var {
        const mon = root.monitorForScreen(screen);
        const mode = Config.monitors?.workspaceMode || "dynamic";
        const raw = Hyprland.workspaces?.values ?? [];
        const existing = [];
        for (let i = 0; i < raw.length; i++) {
            const ws = raw[i];
            if (!ws || ws.id <= 0)
                continue;
            if (mon && ws.monitor && ws.monitor.name && ws.monitor.name !== mon.name)
                continue;
            existing.push(ws);
        }
        existing.sort((a, b) => a.id - b.id);
        if (mode !== "fixed")
            return existing;
        const range = root.reservedRange(screen);
        if (!range)
            return existing;
        const byId = ({});
        for (let j = 0; j < existing.length; j++)
            byId[existing[j].id] = existing[j];
        const out = [];
        for (let id = range.from; id <= range.to; id++) {
            if (byId[id])
                out.push(byId[id]);
            else
                out.push({ id: id, focused: false, urgent: false, synthetic: true });
        }
        return out;
    }

    Process {
        id: pluginProc
        command: ["hyprctl", "plugin", "list"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.hyprbarsLoaded = this.text.toLowerCase().indexOf("hyprbars") !== -1;
            }
        }
    }
}
