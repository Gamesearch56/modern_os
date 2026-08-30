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
    readonly property var toplevelList: {
        void root.toplevels;
        const t = Hyprland.toplevels;
        if (!t)
            return [];
        const vals = t.values;
        if (vals && vals.length !== undefined)
            return vals;
        return [];
    }
    readonly property var focusedWorkspace: Hyprland.focusedWorkspace
    readonly property var focusedToplevel: Hyprland.focusedToplevel
    readonly property bool focusedFullscreen: {
        void root.focusedToplevel;
        const t = root.focusedToplevel;
        if (!t)
            return false;
        const fs = t.fullscreen;
        if (fs === true || fs === 2)
            return true;
        const ipc = t.lastIpcObject;
        if (!ipc)
            return false;
        const v = ipc.fullscreen;
        return v === true || v === 2 || v === "2";
    }

    readonly property bool _lua: Hyprland.usingLua === true

    function dispatch(cmd: string) {
        try {
            Hyprland.dispatch(cmd);
        } catch (e) {
            Logger.error("Hypr", "dispatch '" + cmd + "' failed: " + e);
        }
    }

    // Hyprland 0.55+ Lua IPC ignores hyprlang strings like "workspace 3".
    // Fixed mode jumps to the assigned monitor; dynamic stays on this one.
    function _monitorSelectorForWorkspace(id: int): string {
        const mons = root._sortedMonitors();
        let mon = null;
        if (id >= 1 && id <= 5)
            mon = mons[0];
        else if (id >= 6 && id <= 10)
            mon = mons[1];
        if (!mon)
            return "";
        const desc = String(mon.description || "");
        return desc.length ? ("desc:" + desc) : String(mon.name || "");
    }

    function focusWorkspace(id: int) {
        const mode = Config.monitors?.workspaceMode || "fixed";
        if (mode === "fixed") {
            const sel = root._monitorSelectorForWorkspace(id);
            if (sel.length > 0) {
                if (root._lua)
                    root.dispatch("hl.dsp.workspace.move({ workspace = \"" + id + "\", monitor = \"" + sel + "\" })");
                else
                    root.dispatch("moveworkspacetomonitor " + id + " " + sel);
            }
        }
        if (root._lua) {
            if (mode === "fixed")
                root.dispatch("hl.dsp.focus({ workspace = " + id + " })");
            else
                root.dispatch("hl.dsp.focus({ workspace = " + id + ", on_current_monitor = true })");
        } else if (mode === "fixed") {
            root.dispatch("workspace " + id);
        } else {
            root.dispatch("focusworkspaceoncurrentmonitor " + id);
        }
    }

    function moveToWorkspace(id: int) {
        const mode = Config.monitors?.workspaceMode || "fixed";
        if (mode === "fixed") {
            const sel = root._monitorSelectorForWorkspace(id);
            if (sel.length > 0) {
                if (root._lua)
                    root.dispatch("hl.dsp.workspace.move({ workspace = \"" + id + "\", monitor = \"" + sel + "\" })");
                else
                    root.dispatch("moveworkspacetomonitor " + id + " " + sel);
            }
        }
        if (root._lua)
            root.dispatch("hl.dsp.window.move({ workspace = " + id + " })");
        else
            root.dispatch("movetoworkspace " + id);
    }

    function _rangeForId(id: int): var {
        if (id >= 1 && id <= 5)
            return ({ from: 1, to: 5 });
        if (id >= 6 && id <= 10)
            return ({ from: 6, to: 10 });
        return null;
    }

    function closeWorkspace(id: int) {
        const n = Number(id);
        if (n <= 0)
            return;
        const mons = Hyprland.monitors?.values ?? [];
        let active = false;
        for (let i = 0; i < mons.length; i++) {
            const aw = mons[i]?.activeWorkspace;
            if (aw && Number(aw.id ?? aw) === n)
                active = true;
        }
        const range = root._rangeForId(n);
        const fallback = range ? (n > range.from ? n - 1 : (n < range.to ? n + 1 : 0)) : 0;
        if (active && fallback > 0)
            root.focusWorkspace(fallback);
        const list = Hyprland.toplevels?.values ?? [];
        for (let i = 0; i < list.length; i++) {
            const t = list[i];
            const ws = t?.workspace ? Number(t.workspace.id) : 0;
            if (ws !== n)
                continue;
            const addr = String(t.address || "");
            if (!addr.length)
                continue;
            if (root._lua)
                root.dispatch("hl.dsp.window.close({ window = \"address:" + addr + "\" })");
            else
                root.dispatch("closewindow address:" + addr);
        }
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

    function activateWindow(address: string) {
        const addr = String(address || "");
        if (!addr.length)
            return;
        const t = root.toplevelByAddress(addr);
        const wsId = t && t.workspace ? Number(t.workspace.id) : 0;
        const ipc = t ? t.lastIpcObject : null;
        const hidden = !!(ipc && (ipc.hidden === true || ipc.mapped === false));
        if (wsId < 0 || hidden)
            root.moveToCurrentWorkspace(addr);
        else if (wsId > 0)
            root.focusWorkspace(wsId);
        root.focusWindow(addr);
    }

    function moveToCurrentWorkspace(address: string) {
        const addr = String(address || "");
        if (!addr.length)
            return;
        const fw = root.focusedWorkspace;
        const id = (fw && Number(fw.id) > 0) ? Number(fw.id) : 1;
        if (root._lua)
            root.dispatch("hl.dsp.window.move({ workspace = " + id + ", window = \"address:" + addr + "\" })");
        else
            root.dispatch("movetoworkspace " + id + ",address:" + addr);
    }

    function moveToBackground(address: string) {
        const addr = String(address || "");
        if (!addr.length)
            return;
        if (root._lua)
            root.dispatch("hl.dsp.window.move({ workspace = \"special:background\", silent = true, window = \"address:" + addr + "\" })");
        else
            root.dispatch("movetoworkspacesilent special:background,address:" + addr);
    }

    function raiseDesktop(desktopId: string): bool {
        const id = String(desktopId || "");
        if (!id.length)
            return false;
        const list = Hyprland.toplevels?.values ?? [];
        for (let i = 0; i < list.length; i++) {
            const t = list[i];
            if (!t || !root._windowMatchesDesktop(t, id))
                continue;
            root.activateWindow(String(t.address || ""));
            return true;
        }
        return false;
    }

    function _normId(s: string): string {
        return String(s || "").replace(/\.desktop$/i, "").toLowerCase().replace(/[\s._-]+/g, "");
    }

    function _windowMatchesDesktop(toplevel: var, desktopId: string): bool {
        const needle = root._normId(desktopId);
        if (!needle.length)
            return false;
        const ipc = toplevel.lastIpcObject || ({});
        const fields = [ipc.class, ipc.initialClass, toplevel.class, toplevel.initialClass, ipc.title, toplevel.title];
        for (let i = 0; i < fields.length; i++) {
            const n = root._normId(String(fields[i] || ""));
            if (!n.length)
                continue;
            if (n === needle)
                return true;
            if (needle.length >= 5 && n.indexOf(needle) !== -1)
                return true;
            if (n.length >= 5 && needle.indexOf(n) !== -1)
                return true;
        }
        return false;
    }

    function toplevelByAddress(address: string): var {
        const addr = String(address || "");
        const list = Hyprland.toplevels?.values ?? [];
        for (let i = 0; i < list.length; i++) {
            if (list[i] && String(list[i].address || "") === addr)
                return list[i];
        }
        return null;
    }

    function closeWindow(address: string) {
        const addr = String(address || "");
        if (!addr.length) {
            if (root._lua)
                root.dispatch("hl.dsp.window.close()");
            else
                root.dispatch("killactive");
            return;
        }
        if (root._lua)
            root.dispatch("hl.dsp.window.close({ window = \"address:" + addr + "\" })");
        else
            root.dispatch("closewindow address:" + addr);
    }

    function windowOnScreen(toplevel: var, screen: var): bool {
        const mon = root.monitorForScreen(screen);
        if (!mon || !toplevel)
            return true;
        const ipc = toplevel.lastIpcObject;
        const wsId = toplevel.workspace ? Number(toplevel.workspace.id) : 0;
        const hidden = !!(ipc && (ipc.hidden === true || ipc.mapped === false));
        const special = wsId < 0;
        if (ipc && ipc.monitor !== undefined && ipc.monitor !== null && ipc.monitor !== "") {
            const mid = Number(ipc.monitor);
            if (!Number.isNaN(mid) && mid < 0)
                return root._taskbarOnFocused(screen);
            if (!Number.isNaN(mid) && mon.id !== undefined && Number(mon.id) === mid)
                return true;
            if (String(ipc.monitor) === String(mon.name))
                return true;
            return false;
        }
        if (hidden || special)
            return root._taskbarOnFocused(screen);
        return root._onMonitor(toplevel.workspace, mon);
    }

    function _taskbarOnFocused(screen: var): bool {
        const name = screen && screen.name ? String(screen.name) : "";
        if (!name.length)
            return true;
        return name === root.focusedMonitorName();
    }

    function toggleFloating(address: string) {
        const addr = String(address || "");
        if (!addr.length)
            return;
        root.dispatch("togglefloating address:" + addr);
    }

    function toggleFullscreen(address: string) {
        const addr = String(address || "");
        if (!addr.length)
            return;
        root.dispatch("fullscreen 0,address:" + addr);
    }

    function reload() {
        if (root._lua)
            root.dispatch("hl.reload()");
        else
            root.dispatch("reload");
    }

    function focusedMonitorName(): string {
        void root.focusedWorkspace;
        void root.monitors;
        try {
            const fm = Hyprland.focusedMonitor;
            if (fm && fm.name)
                return String(fm.name);
        } catch (e) {
        }
        const fw = root.focusedWorkspace;
        const wm = fw ? fw.monitor : null;
        if (typeof wm === "string")
            return wm;
        if (wm && wm.name)
            return String(wm.name);
        return "";
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
        void root.toplevelList;
        return (root.toplevelList || []).length;
    }

    function refreshToplevels() {
        try {
            Hyprland.refreshToplevels();
        } catch (e) {
            Logger.warn("Hypr", "refreshToplevels: " + e);
        }
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
        const seen = ({});
        const shown = [];
        function add(id) {
            const n = Number(id);
            if (n <= 0 || seen[n])
                return;
            seen[n] = true;
            shown.push(n);
        }
        const mon = root.monitorForScreen(screen);
        const raw = Hyprland.workspaces?.values ?? [];
        for (let i = 0; i < raw.length; i++) {
            const ws = raw[i];
            if (!ws || Number(ws.id) <= 0)
                continue;
            if (mon && !root._onMonitor(ws, mon))
                continue;
            const id = Number(ws.id);
            if (root.isActiveOnScreen(screen, id) || root._workspaceHasWindows(id))
                add(id);
        }
        if (mon) {
            const aw = mon.activeWorkspace ?? mon.lastIpcObject?.activeWorkspace;
            const awId = Number(aw && aw.id !== undefined ? aw.id : aw);
            if (awId > 0)
                add(awId);
        }
        shown.sort((a, b) => a - b);
        return shown;
    }

    Component.onCompleted: root.refreshToplevels()

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
