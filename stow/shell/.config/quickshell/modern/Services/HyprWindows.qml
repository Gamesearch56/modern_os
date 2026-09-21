// Window matching, focus, close, float. Host is the Hypr singleton
// (dispatch + workspace focus). Keeps Hypr.qml under the line cap.
import Quickshell.Hyprland
import QtQuick

QtObject {
    id: root

    property var host: null
    readonly property HyprAutostart autostart: HyprAutostart {
        windows: root
    }

    function focusWindow(address: string) {
        const addr = String(address || "");
        if (!addr.length)
            return;
        if (root.host._lua)
            root.host.dispatch("hl.dsp.focus({ window = \"address:" + addr + "\" })");
        else
            root.host.dispatch("focuswindow address:" + addr);
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
            root.host.focusWorkspace(wsId);
        root.focusWindow(addr);
    }

    function isWorkspaceToplevel(toplevel: var): bool {
        if (!toplevel)
            return false;
        const ipc = toplevel.lastIpcObject || ({});
        const cls = String(ipc.class || toplevel.class || "").toLowerCase();
        if (cls.indexOf("quickshell") !== -1)
            return false;
        const raw = toplevel.workspace?.id ?? ipc.workspace?.id ?? ipc.workspace;
        const wsId = Number(raw);
        if (!(wsId > 0))
            return false;
        if (ipc.hidden === true || ipc.mapped === false)
            return false;
        return true;
    }

    function moveToCurrentWorkspace(address: string) {
        const fw = root.host.focusedWorkspace;
        const id = (fw && Number(fw.id) > 0) ? Number(fw.id) : 1;
        root.moveWindowToWorkspace(address, id);
    }

    function moveWindowToWorkspace(address: string, id: int) {
        const n = Number(id);
        if (n <= 0 || !root.host)
            return;
        root.host._pinWorkspace(n);
        const addr = String(address || "").replace(/^address:/i, "");
        const win = addr.length ? ", window = \"address:" + addr + "\"" : "";
        if (root.host._lua)
            root.host.dispatch("hl.dsp.window.move({ workspace = " + n + win + " })");
        else if (addr.length)
            root.host.dispatch("movetoworkspace " + n + ",address:" + addr);
        else
            root.host.dispatch("movetoworkspace " + n);
    }

    function moveToBackground(address: string) {
        const addr = String(address || "");
        if (!addr.length)
            return;
        if (root.host._lua)
            root.host.dispatch("hl.dsp.window.move({ workspace = \"special:background\", silent = true, window = \"address:" + addr + "\" })");
        else
            root.host.dispatch("movetoworkspacesilent special:background,address:" + addr);
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
            // Vivaldi --app= uses URL-derived classes (mail.proton.me, …).
            if (n.indexOf("vivaldi") === 0) {
                if (needle.indexOf("mail") !== -1 && n.indexOf("mailproton") !== -1)
                    return true;
                if (needle.indexOf("calendar") !== -1 && n.indexOf("calendarproton") !== -1)
                    return true;
                if (needle.indexOf("whatsapp") !== -1 && n.indexOf("whatsapp") !== -1)
                    return true;
            }
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

    function _addrKey(address: string): string {
        return String(address || "").replace(/^address:/i, "").toLowerCase();
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
        const addr = String(address || "").replace(/^address:/i, "");
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
        const addr = String(address || "").replace(/^address:/i, "");
        if (!addr.length || !root.host._lua)
            return;
        root.host.dispatch("hl.dsp.window.kill({ window = 'address:" + addr + "' })");
    }

    function windowOnScreen(toplevel: var, screen: var): bool {
        const mon = root.host.monitorForScreen(screen);
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
        return root.host._onMonitor(toplevel.workspace, mon);
    }

    function _taskbarOnFocused(screen: var): bool {
        const name = screen && screen.name ? String(screen.name) : "";
        if (!name.length)
            return true;
        return name === root.host.focusedMonitorName();
    }

    function toggleFloating(address: string) {
        const addr = String(address || "");
        if (!addr.length)
            return;
        root.host.dispatch("togglefloating address:" + addr);
    }

    function toggleFullscreen(address: string) {
        const addr = String(address || "");
        if (!addr.length)
            return;
        root.host.dispatch("fullscreen 0,address:" + addr);
    }

    function toggleSplit(address: string) {
        const addr = String(address || "").replace(/^address:/i, "");
        if (addr.length)
            root.focusWindow(addr);
        if (root.host._lua)
            root.host.dispatch("hl.dsp.layout(\"togglesplit\")");
        else
            root.host.dispatch("togglesplit");
    }
}
