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

    readonly property bool _lua: Hyprland.usingLua === true

    function dispatch(cmd: string) {
        try {
            Hyprland.dispatch(cmd);
        } catch (e) {
            Logger.error("Hypr", "dispatch '" + cmd + "' failed: " + e);
        }
    }

    // Hyprland 0.55+ Lua IPC ignores hyprlang strings like "workspace 3".
    function focusWorkspace(id: int) {
        if (root._lua)
            root.dispatch("hl.dsp.focus({ workspace = " + id + " })");
        else
            root.dispatch("workspace " + id);
    }

    function moveToWorkspace(id: int) {
        if (root._lua)
            root.dispatch("hl.dsp.window.move({ workspace = " + id + " })");
        else
            root.dispatch("movetoworkspace " + id);
    }

    function focusWindow(address: string) {
        const addr = String(address || "");
        if (!addr.length)
            return;
        if (root._lua)
            root.dispatch("hl.dsp.focus({ window = \"address:" + addr + "\" })");
        else
            root.dispatch("focuswindow address:" + addr);
    }

    function closeWindow(address: string) {
        const addr = String(address || "");
        if (root._lua) {
            if (addr.length)
                root.focusWindow(addr);
            root.dispatch("hl.dsp.window.close()");
            return;
        }
        if (addr.length)
            root.dispatch("closewindow address:" + addr);
        else
            root.dispatch("killactive");
    }

    function reload() {
        if (root._lua)
            root.dispatch("hl.reload()");
        else
            root.dispatch("reload");
    }

    function monitorForScreen(screen: var): var {
        if (!screen)
            return null;
        try {
            const hit = Hyprland.monitorFor(screen);
            if (hit)
                return hit;
        } catch (e) {
        }
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
            if (mons[i].name === mon.name) {
                idx = i;
                break;
            }
        }
        if (idx === 0)
            return ({ from: 1, to: 5 });
        if (idx === 1)
            return ({ from: 6, to: 10 });
        return null;
    }

    function _onMonitor(ws: var, mon: var): bool {
        if (!ws || !mon)
            return true;
        const wm = ws.monitor;
        if (!wm)
            return true;
        if (typeof wm === "string")
            return wm === mon.name;
        if (wm.name)
            return wm.name === mon.name;
        return true;
    }

    function workspaceById(id: int): var {
        const raw = Hyprland.workspaces?.values ?? [];
        for (let i = 0; i < raw.length; i++) {
            if (raw[i] && Number(raw[i].id) === id)
                return raw[i];
        }
        return null;
    }

    function isActiveOnScreen(screen: var, id: int): bool {
        const mon = root.monitorForScreen(screen);
        if (!mon)
            return false;
        const aw = mon.activeWorkspace ?? mon.lastIpcObject?.activeWorkspace;
        if (aw && Number(aw.id ?? aw) === id)
            return true;
        const fw = Hyprland.focusedWorkspace;
        if (fw && Number(fw.id) === id && root._onMonitor(fw, mon))
            return true;
        return false;
    }

    function taskbarCount(screen: var): int {
        void root.toplevels;
        void root.monitors;
        void root.focusedWorkspace;
        const list = Hyprland.toplevels?.values ?? [];
        let n = 0;
        for (let i = 0; i < list.length; i++) {
            const id = list[i]?.workspace ? Number(list[i].workspace.id) : 0;
            if (id > 0 && root.isActiveOnScreen(screen, id))
                n++;
        }
        return n;
    }

    function _workspaceHasWindows(id: int): bool {
        const list = Hyprland.toplevels?.values ?? [];
        for (let i = 0; i < list.length; i++) {
            if (list[i]?.workspace && Number(list[i].workspace.id) === id)
                return true;
        }
        const ws = root.workspaceById(id);
        return Number(ws?.windows ?? ws?.lastIpcObject?.windows ?? 0) > 0;
    }

    function workspaceIdsFor(screen: var): var {
        void root.workspaces;
        void root.monitors;
        void root.toplevels;
        void root.focusedWorkspace;
        const mode = Config.monitors?.workspaceMode || "fixed";
        const ids = [];
        if (mode === "fixed") {
            const range = root.reservedRange(screen);
            if (range) {
                for (let id = range.from; id <= range.to; id++)
                    ids.push(id);
            }
        }
        if (ids.length === 0) {
            const mon = root.monitorForScreen(screen);
            const raw = Hyprland.workspaces?.values ?? [];
            for (let i = 0; i < raw.length; i++) {
                const ws = raw[i];
                if (!ws || ws.id <= 0)
                    continue;
                if (mon && !root._onMonitor(ws, mon))
                    continue;
                ids.push(Number(ws.id));
            }
            ids.sort((a, b) => a - b);
        }
        const shown = [];
        for (let i = 0; i < ids.length; i++) {
            const id = ids[i];
            if (root.isActiveOnScreen(screen, id) || root._workspaceHasWindows(id))
                shown.push(id);
        }
        return shown;
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
