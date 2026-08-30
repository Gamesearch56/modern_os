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
        const mode = Config.monitors?.workspaceMode || "dynamic";
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
        const mode = Config.monitors?.workspaceMode || "dynamic";
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
        if (root._raiseMatching(id, true))
            return true;
        return root._raiseMatching(id, false);
    }

    function _raiseMatching(desktopId: string, classOnly: bool): bool {
        const list = Hyprland.toplevels?.values ?? [];
        for (let i = 0; i < list.length; i++) {
            const t = list[i];
            if (!t)
                continue;
            const ok = classOnly ? root._windowMatchesClass(t, desktopId) : root._windowMatchesDesktop(t, desktopId);
            if (!ok)
                continue;
            root.activateWindow(String(t.address || ""));
            return true;
        }
        return false;
    }

    function _normId(s: string): string {
        return String(s || "").replace(/\.desktop$/i, "").toLowerCase().replace(/[\s._-]+/g, "");
    }

    function _classFields(toplevel: var): var {
        const ipc = toplevel.lastIpcObject || ({});
        return [ipc.class, ipc.initialClass, toplevel.class, toplevel.initialClass];
    }

    function _windowMatchesClass(toplevel: var, desktopId: string): bool {
        const needle = root._normId(desktopId);
        if (!needle.length)
            return false;
        const fields = root._classFields(toplevel);
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

    function _windowMatchesDesktop(toplevel: var, desktopId: string): bool {
        if (root._windowMatchesClass(toplevel, desktopId))
            return true;
        const needle = root._normId(desktopId);
        if (!needle.length)
            return false;
        const ipc = toplevel.lastIpcObject || ({});
        const fields = [ipc.title, toplevel.title];
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

    function keyword(key: string, value: string) {
        const k = String(key || "");
        if (!k.length)
            return;
        const v = String(value);
        if (root._lua) {
            const parts = k.split(":");
            if (parts.length !== 2)
                return;
            let lit = v;
            if (v !== "true" && v !== "false" && !/^-?\d+(\.\d+)?$/.test(v))
                lit = JSON.stringify(v);
            Quickshell.execDetached([
                "hyprctl", "eval",
                "hl.config({ " + parts[0] + " = { " + parts[1] + " = " + lit + " } })"
            ]);
            return;
        }
        Quickshell.execDetached(["hyprctl", "keyword", k, v]);
    }

    function setCursor(theme: string, size: int) {
        const t = String(theme || "").trim();
        if (!t.length)
            return;
        const n = size > 0 ? size : 24;
        Quickshell.execDetached([
            Quickshell.env("HOME") + "/modern_dotfile/scripts/cursor-apply.sh",
            t, String(n)
        ]);
    }

    function syncInput(path: string, value: var) {
        const p = String(path || "");
        const input = Config.input || {};
        if (p === "input.kbLayout")
            root.keyword("input:kb_layout", String(value || input.kbLayout || "de"));
        else if (p === "input.repeatRate")
            root.keyword("input:repeat_rate", String(Math.round(Number(value ?? input.repeatRate ?? 25))));
        else if (p === "input.repeatDelay")
            root.keyword("input:repeat_delay", String(Math.round(Number(value ?? input.repeatDelay ?? 600))));
        else if (p === "input.numlockOnBoot")
            root.keyword("input:numlock_by_default", value ? "true" : "false");
    }

    function syncAppearance(path: string, value: var) {
        const p = String(path || "");
        if (p === "input.kbLayout" || p === "input.repeatRate"
                || p === "input.repeatDelay" || p === "input.numlockOnBoot") {
            root.syncInput(p, value);
            return;
        }
        const win = (p === "windows" && value && typeof value === "object")
            ? value : (Config.windows || {});
        const design = (p === "design" && value && typeof value === "object")
            ? value : (Config.design || {});
        if (p === "windows.gapsIn")
            root.keyword("general:gaps_in", String(value ?? win.gapsIn ?? 5));
        else if (p === "windows.gapsOut")
            root.keyword("general:gaps_out", String(value ?? win.gapsOut ?? 10));
        else if (p === "windows.opacity") {
            const a = value ?? win.opacity ?? 1;
            root.keyword("decoration:active_opacity", String(a));
            root.keyword("decoration:inactive_opacity", String(Math.min(1, a * 0.98)));
        } else if (p === "windows") {
            root.keyword("general:gaps_in", String(win.gapsIn ?? 5));
            root.keyword("general:gaps_out", String(win.gapsOut ?? 10));
            const a = win.opacity ?? 1;
            root.keyword("decoration:active_opacity", String(a));
            root.keyword("decoration:inactive_opacity", String(Math.min(1, a * 0.98)));
        } else if (p === "design.cornerRounding") {
            const r = value ?? design.cornerRounding ?? 1;
            root.keyword("decoration:rounding", String(Math.floor(16 * r)));
        } else if (p === "design.cursorTheme" || p === "design.cursorSize") {
            const theme = p === "design.cursorTheme"
                ? String(value || design.cursorTheme || "")
                : String(design.cursorTheme || "");
            const size = p === "design.cursorSize"
                ? (value || 24) : (design.cursorSize ?? 24);
            root.setCursor(theme, size);
        } else if (p === "design") {
            const r = design.cornerRounding ?? 1;
            root.keyword("decoration:rounding", String(Math.floor(16 * r)));
            root.setCursor(String(design.cursorTheme || ""), design.cursorSize ?? 24);
        }
    }

    property var cursorThemes: []

    function refreshCursorThemes() {
        cursorProc.running = false;
        Qt.callLater(() => {
            cursorProc.running = true;
        });
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
        const n = Number(id);
        if (n <= 0)
            return false;
        const list = Hyprland.toplevels?.values ?? [];
        for (let i = 0; i < list.length; i++) {
            const t = list[i];
            if (!t || !t.workspace || Number(t.workspace.id) !== n)
                continue;
            const ipc = t.lastIpcObject || ({});
            if (ipc.hidden === true || ipc.mapped === false)
                continue;
            const cls = String(ipc.class || t.class || "").toLowerCase();
            if (cls.indexOf("quickshell") !== -1)
                continue;
            return true;
        }
        return false;
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
        const mode = Config.monitors?.workspaceMode || "dynamic";
        const range = root.reservedRange(screen);
        const raw = Hyprland.workspaces?.values ?? [];
        for (let i = 0; i < raw.length; i++) {
            const ws = raw[i];
            if (!ws || Number(ws.id) <= 0)
                continue;
            if (mon && !root._onMonitor(ws, mon))
                continue;
            const id = Number(ws.id);
            if (mode === "fixed" && range && (id < range.from || id > range.to))
                continue;
            if (root.isActiveOnScreen(screen, id) || root._workspaceHasWindows(id))
                add(id);
        }
        if (mon) {
            const aw = mon.activeWorkspace ?? mon.lastIpcObject?.activeWorkspace;
            const awId = Number(aw && aw.id !== undefined ? aw.id : aw);
            if (awId > 0 && !(mode === "fixed" && range && (awId < range.from || awId > range.to)))
                add(awId);
        }
        shown.sort((a, b) => a - b);
        return shown;
    }

    property var monitorDump: []
    property int monitorGen: 0

    function refreshMonitorDump() {
        dumpProc.running = false;
        Qt.callLater(() => {
            dumpProc.running = true;
        });
    }

    function _ipc(mon: var): var {
        if (!mon)
            return ({});
        const desc = String(mon.description || "");
        const dump = root.monitorDump || [];
        for (let i = 0; i < dump.length; i++) {
            if (String(dump[i].description || "") === desc)
                return dump[i];
        }
        const ipc = mon.lastIpcObject;
        if (ipc && typeof ipc === "object")
            return ipc;
        return ({});
    }

    function parseMode(spec: string): var {
        const s = String(spec || "");
        const m = s.match(/^(\d+)x(\d+)@([\d.]+)/);
        if (!m)
            return null;
        return {
            w: Number(m[1]),
            h: Number(m[2]),
            hz: Number(m[3]),
            mode: m[1] + "x" + m[2] + "@" + m[3]
        };
    }

    function hzFor(mon: var): int {
        const ipc = root._ipc(mon);
        let hz = Number(ipc.refreshRate ?? 0);
        if (!(hz > 1))
            hz = Number(mon?.refreshRate ?? 0);
        if (hz > 1)
            return Math.round(hz);
        const modes = root._modesRaw(mon);
        if (modes.length) {
            const p = root.parseMode(modes[0]);
            return p ? Math.round(p.hz) : 0;
        }
        return 0;
    }

    function _modesRaw(mon: var): var {
        const ipc = root._ipc(mon);
        if (ipc.availableModes && ipc.availableModes.length)
            return ipc.availableModes;
        if (mon && mon.availableModes && mon.availableModes.length)
            return mon.availableModes;
        return [];
    }

    function resolutionsFor(mon: var): var {
        const seen = ({});
        const out = [];
        const modes = root._modesRaw(mon);
        for (let i = 0; i < modes.length; i++) {
            const p = root.parseMode(modes[i]);
            if (!p)
                continue;
            const key = p.w + "x" + p.h;
            if (seen[key])
                continue;
            seen[key] = true;
            out.push({ value: key, titleValue: p.w + " × " + p.h, w: p.w, h: p.h });
        }
        return out;
    }

    function ratesFor(mon: var, w: int, h: int): var {
        const seen = ({});
        const out = [];
        const modes = root._modesRaw(mon);
        for (let i = 0; i < modes.length; i++) {
            const p = root.parseMode(modes[i]);
            if (!p || p.w !== w || p.h !== h)
                continue;
            const key = String(p.hz);
            if (seen[key])
                continue;
            seen[key] = true;
            out.push({
                value: key,
                titleValue: Math.round(p.hz) + " Hz",
                hz: p.hz,
                mode: p.mode
            });
        }
        out.sort((a, b) => b.hz - a.hz);
        return out;
    }

    function bestMode(mon: var, w: int, h: int, preferHz: real): string {
        const rates = root.ratesFor(mon, w, h);
        if (!rates.length)
            return "";
        const want = Number(preferHz);
        for (let i = 0; i < rates.length; i++) {
            if (Math.abs(rates[i].hz - want) < 0.6)
                return rates[i].mode;
        }
        return rates[0].mode;
    }

    function monitorByDesc(desc: string): var {
        const want = String(desc || "");
        const list = root.monitors?.values ?? [];
        for (let i = 0; i < list.length; i++) {
            if (String(list[i].description || "") === want)
                return list[i];
        }
        return null;
    }

    readonly property int monitorCount: {
        void root.monitors;
        return (root.monitors?.values ?? []).length;
    }

    onMonitorCountChanged: root.refreshMonitorDump()

    Component.onCompleted: {
        root.refreshToplevels();
        root.refreshMonitorDump();
    }

    Process {
        id: dumpProc
        running: false
        command: ["hyprctl", "-j", "monitors"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(this.text);
                    root.monitorDump = Array.isArray(j) ? j : [];
                } catch (e) {
                    root.monitorDump = [];
                }
                root.monitorGen++;
            }
        }
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

    Process {
        id: cursorProc
        running: false
        command: [Quickshell.env("HOME") + "/modern_dotfile/scripts/cursor-themes.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.cursorThemes = this.text.trim().split("\n").filter(s => s.length > 0);
            }
        }
    }
}
