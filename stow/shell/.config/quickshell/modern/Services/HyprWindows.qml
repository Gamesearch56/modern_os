// Window matching, focus, close. Host is the Hypr singleton.
// Raise/float helpers live in HyprRaise (line cap).
import Quickshell
import Quickshell.Hyprland
import QtQuick
import "../Commons"

QtObject {
    id: root

    property var host: null
    readonly property HyprAutostart autostart: HyprAutostart {
        windows: root
    }
    readonly property HyprRaise raise: HyprRaise {
        windows: root
    }

    // Quickshell omits 0x; Hyprland Lua needs address:0x… or moves are no-ops.
    function _addrHypr(address: string): string {
        let a = String(address || "").replace(/^address:/i, "").trim();
        if (!a.length)
            return "";
        if (a.toLowerCase().indexOf("0x") !== 0)
            a = "0x" + a;
        return a;
    }

    function _addrKey(address: string): string {
        return root._addrHypr(address).toLowerCase();
    }

    function focusWindow(address: string) {
        const addr = root._addrHypr(address);
        if (!addr.length)
            return;
        if (root.host._lua)
            root.host.dispatch("hl.dsp.focus({ window = \"address:" + addr + "\" })");
        else
            root.host.dispatch("focuswindow address:" + addr);
    }

    function activateWindow(address: string) {
        const addr = root._addrHypr(address);
        if (!addr.length)
            return;
        const t = root.toplevelByAddress(addr);
        const wsId = t && t.workspace ? Number(t.workspace.id) : 0;
        const ipc = t ? t.lastIpcObject : null;
        const hidden = !!(ipc && (ipc.hidden === true || ipc.mapped === false));
        if (wsId < 0 || hidden)
            root.moveToCurrentWorkspace(addr);
        else if (wsId > 0)
            root.host.focusWorkspace(wsId);
        root.focusWindow(addr);
    }

    function _overlayTitle(title: string): bool {
        const t = String(title || "");
        return t === "modern.overview" || t === "modern.settings"
            || t === "modern.store" || t === "modern.wallpaper"
            || t === "modern.cheatsheet" || t === "modern.wallpaper-provider";
    }

    function isWorkspaceToplevel(toplevel: var): bool {
        if (!toplevel)
            return false;
        const ipc = toplevel.lastIpcObject || ({});
        const cls = String(ipc.class || toplevel.class || "").toLowerCase();
        if (cls.indexOf("quickshell") !== -1)
            return false;
        if (root._overlayTitle(String(ipc.title || toplevel.title || ipc.initialTitle || "")))
            return false;
        const wsId = Number(toplevel.workspace?.id ?? ipc.workspace?.id ?? ipc.workspace);
        return wsId > 0 && ipc.hidden !== true && ipc.mapped !== false;
    }

    function moveToCurrentWorkspace(address: string) {
        const fw = root.host.focusedWorkspace;
        const id = (fw && Number(fw.id) > 0) ? Number(fw.id) : 1;
        root.moveWindowToWorkspace(address, id, true);
    }

    function moveWindowToWorkspace(address: string, id: int, follow: bool) {
        const n = Number(id);
        if (n <= 0 || !root.host)
            return;
        root.host._pinWorkspace(n);
        const addr = root._addrHypr(address);
        const win = addr.length ? ", window = \"address:" + addr + "\"" : "";
        const fol = follow === true ? ", follow = true" : "";
        if (root.host._lua)
            root.host.dispatch("hl.dsp.window.move({ workspace = " + n + fol + win + " })");
        else if (addr.length)
            root.host.dispatch("movetoworkspace " + n + ",address:" + addr);
        else
            root.host.dispatch("movetoworkspace " + n);
    }

    function moveToBackground(address: string) {
        const addr = root._addrHypr(address);
        if (!addr.length)
            return;
        if (root.host._lua)
            root.host.dispatch("hl.dsp.window.move({ workspace = \"special:background\", follow = false, window = \"address:" + addr + "\" })");
        else
            root.host.dispatch("movetoworkspacesilent special:background,address:" + addr);
    }

    function raiseDesktop(desktopId: string): bool {
        return root.raise.raiseDesktop(desktopId);
    }

    function raiseApp(desktopId: string, appName: string): bool {
        return root.raise.raiseApp(desktopId, appName);
    }

    function raiseDesktopOrLaunch(desktopId: string, entry: var): bool {
        return root.raise.raiseDesktopOrLaunch(desktopId, entry);
    }

    function toplevelByAddress(address: string): var {
        const addr = root._addrKey(address);
        if (!addr.length)
            return null;
        const list = Hyprland.toplevels?.values ?? [];
        for (let i = 0; i < list.length; i++) {
            if (list[i] && root._addrKey(list[i].address) === addr)
                return list[i];
        }
        return null;
    }

    function isAutostartWindow(toplevel: var): bool {
        return autostart.isAutostartWindow(toplevel);
    }

    function hideAutostart(address: string): bool {
        return autostart.hide(address);
    }

    function closeFocused(): string {
        const t = Hyprland.focusedToplevel;
        if (!t)
            return "false";
        const addr = String(t.address || "");
        if (!addr.length)
            return "false";
        if (root.hideAutostart(addr))
            return "hidden";
        return "false";
    }

    function closeWindow(address: string) {
        if (root.hideAutostart(address))
            return;
        const addr = root._addrHypr(address);
        if (!addr.length)
            return;
        const t = root.toplevelByAddress(addr);
        if (t && t.wayland && t.wayland.close) {
            t.wayland.close();
            return;
        }
        if (root.host._lua)
            root.host.dispatch("hl.dsp.window.close({ window = 'address:" + addr + "' })");
        else
            root.host.dispatch("closewindow address:" + addr);
    }

    function killWindow(address: string) {
        if (root.hideAutostart(address))
            return;
        root.forceKillWindow(address);
    }

    // Bypass park — Settings Autostart remove only.
    function forceKillWindow(address: string) {
        const addr = root._addrHypr(address);
        if (!addr.length || !root.host)
            return;
        if (root.host._lua)
            root.host.dispatch("hl.dsp.window.kill({ window = 'address:" + addr + "' })");
        else
            root.host.dispatch("killwindow address:" + addr);
    }

    function forceKillAutostart(desktopId: string): int {
        return autostart.forceKillDesktop(desktopId);
    }

    function windowOnScreen(toplevel: var, screen: var): bool {
        const mon = root.host.monitorForScreen(screen);
        if (!mon || !toplevel)
            return true;
        const ipc = toplevel.lastIpcObject;
        const wsId = toplevel.workspace ? Number(toplevel.workspace.id) : 0;
        const hidden = !!(ipc && (ipc.hidden === true || ipc.mapped === false));
        if (ipc && ipc.monitor !== undefined && ipc.monitor !== null && ipc.monitor !== "") {
            const mid = Number(ipc.monitor);
            if (!Number.isNaN(mid) && mid < 0)
                return root._taskbarOnFocused(screen);
            if (!Number.isNaN(mid) && mon.id !== undefined && Number(mon.id) === mid)
                return true;
            return String(ipc.monitor) === String(mon.name);
        }
        if (hidden || wsId < 0)
            return root._taskbarOnFocused(screen);
        return root.host._onMonitor(toplevel.workspace, mon);
    }

    function _taskbarOnFocused(screen: var): bool {
        const name = screen && screen.name ? String(screen.name) : "";
        return !name.length || name === root.host.focusedMonitorName();
    }

    function toggleFloating(address: string) { root.raise.toggleFloating(address); }
    function toggleFullscreen(address: string) { root.raise.toggleFullscreen(address); }
    function toggleSplit(address: string) { root.raise.toggleSplit(address); }
}
