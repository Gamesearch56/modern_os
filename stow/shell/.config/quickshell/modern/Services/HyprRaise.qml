// Raise / activate / float helpers for HyprWindows (line-cap split).
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import "../Commons"

Item {
    id: root

    property var windows: null
    property var _raiseEntry: null

    Process {
        id: raiseProc
        running: false
        command: ["true"]
        onExited: (exitCode) => {
            if (exitCode !== 0 && root._raiseEntry && root._raiseEntry.execute)
                root._raiseEntry.execute();
            root._raiseEntry = null;
        }
    }

    function raiseDesktop(desktopId: string): bool {
        const win = root.windows;
        if (!win)
            return false;
        const id = String(desktopId || "");
        if (!id.length)
            return false;
        try {
            if (Hyprland.refreshToplevels)
                Hyprland.refreshToplevels();
        } catch (e) {
        }
        const list = Hyprland.toplevels?.values ?? [];
        for (let i = 0; i < list.length; i++) {
            const t = list[i];
            if (!t || !win.autostart.matchesDesktop(t, id))
                continue;
            const addr = String(t.address || "");
            if (!addr.length)
                continue;
            win.activateWindow(addr);
            return true;
        }
        return false;
    }

    // Raise/park lifecycle is only for general.autostart (mail/calendar/
    // WhatsApp). Other apps must execute() — raiseDesktop false-positives
    // on stale QS toplevels returned true and skipped Steam/Battle.net.
    function raiseDesktopOrLaunch(desktopId: string, entry: var): bool {
        const id = String(desktopId || "");
        const win = root.windows;
        if (!win || !win.autostart.isAutostartDesktop(id)) {
            if (entry && entry.execute)
                entry.execute();
            return !!(entry && entry.execute);
        }
        if (root.raiseDesktop(id))
            return true;
        const stem = id.replace(/\.desktop$/i, "");
        if (!stem.length) {
            if (entry && entry.execute)
                entry.execute();
            return !!(entry && entry.execute);
        }
        if (raiseProc.running)
            return true;
        root._raiseEntry = entry || null;
        raiseProc.command = [Paths.script("session-raise.sh"), stem];
        raiseProc.running = true;
        return true;
    }

    function toggleFloating(address: string) {
        const win = root.windows;
        const addr = win ? win._addrHypr(address) : "";
        if (!addr.length || !win || !win.host)
            return;
        win.host.dispatch("togglefloating address:" + addr);
    }

    function toggleFullscreen(address: string) {
        const win = root.windows;
        const addr = win ? win._addrHypr(address) : "";
        if (!addr.length || !win || !win.host)
            return;
        win.host.dispatch("fullscreen 0,address:" + addr);
    }

    function toggleSplit(address: string) {
        const win = root.windows;
        const addr = win ? win._addrHypr(address) : "";
        if (!win || !win.host)
            return;
        if (addr.length)
            win.focusWindow(addr);
        if (win.host._lua)
            win.host.dispatch("hl.dsp.layout(\"togglesplit\")");
        else
            win.host.dispatch("togglesplit");
    }
}
