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
    property var _onMiss: null
    property string _parkStem: ""

    Process {
        id: raiseProc
        running: false
        command: ["true"]
        onExited: (exitCode) => {
            const entry = root._raiseEntry;
            const miss = root._onMiss;
            const stem = root._parkStem;
            root._raiseEntry = null;
            root._onMiss = null;
            root._parkStem = "";
            if (exitCode === 0)
                return;
            if (entry && entry.execute) {
                entry.execute();
                // The class rule parks the new window. Move that one
                // here once it exists, so the click still opens it.
                if (stem.length)
                    root._armParkedOpen(stem);
                return;
            }
            if (miss)
                miss();
        }
    }

    // A freshly started background app is not in the client list yet.
    Process {
        id: parkedOpen
        running: false
        command: ["true"]
        property string stem: ""
        property int tries: 0
        onExited: (code) => {
            if (code === 0 || parkedOpen.tries >= 12)
                parkedWait.stop();
        }
    }

    Timer {
        id: parkedWait
        interval: Math.max(Motion.mediumMs, 1)
        repeat: true
        onTriggered: {
            if (parkedOpen.running || !parkedOpen.stem.length)
                return;
            parkedOpen.tries += 1;
            if (parkedOpen.tries > 12) {
                stop();
                return;
            }
            parkedOpen.command = [Paths.script("session-raise.sh"), parkedOpen.stem];
            parkedOpen.running = true;
        }
    }

    function _armParkedOpen(stem: string) {
        parkedWait.stop();
        parkedOpen.stem = stem;
        parkedOpen.tries = 0;
        parkedWait.restart();
    }

    function _stopParkedOpen() {
        parkedWait.stop();
        parkedOpen.stem = "";
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
        let parked = "";
        for (let i = 0; i < list.length; i++) {
            const t = list[i];
            if (!t || !win.autostart.matchesDesktop(t, id))
                continue;
            const addr = String(t.address || "");
            if (!addr.length)
                continue;
            // No numeric id on special:background. Treating that as "on
            // screen" focuses the workspace and shows every parked app.
            if (win.windowParked && win.windowParked(t)) {
                if (!parked.length)
                    parked = addr;
                continue;
            }
            const wsId = t.workspace ? Number(t.workspace.id) : 0;
            if (wsId > 0) {
                win.activateWindow(addr);
                return true;
            }
            if (!parked.length)
                parked = addr;
        }
        if (parked.length) {
            win.activateWindow(parked);
            return true;
        }
        return false;
    }

    function raiseApp(desktopId: string, appName: string, onMiss: var): bool {
        const hints = [desktopId, appName];
        const lookup = String(desktopId || appName || "").replace(/\.desktop$/i, "");
        if (lookup.length) {
            const e = DesktopEntries.byId(lookup) || DesktopEntries.byId(lookup + ".desktop")
                || DesktopEntries.heuristicLookup(String(appName || lookup));
            if (e)
                hints.push(e.id, e.startupClass, e.name);
        }
        const seen = {};
        for (let i = 0; i < hints.length; i++) {
            const n = String(hints[i] || "").replace(/\.desktop$/i, "").trim();
            const k = n.toLowerCase();
            if (!n.length || seen[k])
                continue;
            seen[k] = true;
            if (root.raiseDesktop(n))
                return true;
        }
        // Quickshell's toplevel list misses clients on special:background.
        // Hyprland still has them; the script moves that one window here.
        const stem = String(desktopId || appName || "").replace(/\.desktop$/i, "").trim();
        if (!stem.length) {
            if (onMiss)
                onMiss();
            return false;
        }
        if (raiseProc.running)
            return true;
        root._stopParkedOpen();
        root._raiseEntry = null;
        root._parkStem = "";
        root._onMiss = onMiss || null;
        raiseProc.command = [Paths.script("session-raise.sh"), stem];
        raiseProc.running = true;
        return true;
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
        root._stopParkedOpen();
        root._raiseEntry = entry || null;
        root._parkStem = stem;
        raiseProc.command = [Paths.script("session-raise.sh"), stem];
        raiseProc.running = true;
        return true;
    }

    function toggleFloating(address: string) {
        const win = root.windows;
        const addr = win ? win._addrHypr(address) : "";
        if (!addr.length || !win || !win.host)
            return;
        win.focusWindow(addr);
        if (win.host._lua)
            win.host.dispatch("hl.dsp.window.float({ action = \"toggle\", window = \"address:" + addr + "\" })");
        else
            win.host.dispatch("togglefloating address:" + addr);
    }

    function toggleFullscreen(address: string) {
        const win = root.windows;
        const addr = win ? win._addrHypr(address) : "";
        if (!addr.length || !win || !win.host)
            return;
        win.focusWindow(addr);
        if (win.host._lua)
            win.host.dispatch("hl.dsp.window.fullscreen({ window = \"address:" + addr + "\" })");
        else
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
