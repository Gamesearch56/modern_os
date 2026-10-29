// Close of general.autostart apps hides them on special:background.
import Quickshell.Hyprland
import QtQuick
import "../Commons"

QtObject {
    id: root

    property var windows: null

    function _norm(s: string): string {
        return String(s || "").replace(/\.desktop$/i, "").toLowerCase()
            .replace(/[-_]?url[-_]?handler$/i, "").replace(/[\s._-]+/g, "");
    }

    function _stem(id: string): string {
        return String(id || "").replace(/\.desktop$/i, "");
    }

    // URL tokens without requiring a vivaldi* class prefix.
    function _urlTokens(needle: string, fieldn: string): bool {
        if (!needle.length || !fieldn.length)
            return false;
        if (needle.indexOf("mail") !== -1
                && (fieldn.indexOf("mailproton") !== -1 || fieldn.indexOf("mailprotonme") !== -1))
            return true;
        if (needle.indexOf("calendar") !== -1
                && (fieldn.indexOf("calendarproton") !== -1 || fieldn.indexOf("calendarprotonme") !== -1))
            return true;
        if (needle.indexOf("whatsapp") !== -1
                && (fieldn.indexOf("whatsapp") !== -1 || fieldn.indexOf("webwhatsapp") !== -1))
            return true;
        return false;
    }

    function _fieldMatches(raw: var, desktopId: string): bool {
        const needle = root._norm(desktopId);
        const fieldn = root._norm(String(raw || ""));
        if (!needle.length || !fieldn.length)
            return false;
        if (root._urlTokens(needle, fieldn))
            return true;
        if (fieldn === needle)
            return true;
        // Needle inside field only — reverse match yanked unrelated windows.
        if (needle.length >= 5 && fieldn.indexOf(needle) !== -1)
            return true;
        return false;
    }

    function _fields(toplevel: var): var {
        if (!toplevel)
            return [];
        const ipc = toplevel.lastIpcObject || ({});
        return [
            ipc.class, ipc.initialClass, toplevel.class, toplevel.initialClass,
            ipc.title, toplevel.title, ipc.initialTitle, toplevel.initialTitle
        ];
    }

    function matchesDesktop(toplevel: var, desktopId: string): bool {
        if (!toplevel || !String(desktopId || "").length)
            return false;
        const fields = root._fields(toplevel);
        for (let k = 0; k < fields.length; k++) {
            if (root._fieldMatches(fields[k], desktopId))
                return true;
        }
        return false;
    }

    function isAutostartDesktop(desktopId: string): bool {
        const list = Config.general.autostart || [];
        const want = root._norm(desktopId);
        if (!want.length || list.length === 0)
            return false;
        for (let j = 0; j < list.length; j++) {
            if (root._norm(list[j]) === want)
                return true;
        }
        return false;
    }

    function isAutostartWindow(toplevel: var): bool {
        const list = Config.general.autostart || [];
        if (!toplevel || list.length === 0)
            return false;
        for (let j = 0; j < list.length; j++) {
            if (root.matchesDesktop(toplevel, list[j]))
                return true;
        }
        return false;
    }

    function hide(address: string): bool {
        const win = root.windows;
        if (!win)
            return false;
        const addr = win._addrHypr ? win._addrHypr(address) : String(address || "").replace(/^address:/i, "");
        if (!addr.length)
            return false;
        const t = win.toplevelByAddress(addr);
        if (!t || !root.isAutostartWindow(t))
            return false;
        win.moveToBackground(addr);
        return true;
    }

    // Settings Autostart close — real kill, bypass park.
    function forceKillDesktop(desktopId: string): int {
        const win = root.windows;
        if (!win)
            return 0;
        const id = root._stem(desktopId);
        if (!id.length)
            return 0;
        const list = Hyprland.toplevels?.values ?? [];
        let n = 0;
        for (let i = 0; i < list.length; i++) {
            const t = list[i];
            if (!t || !root.matchesDesktop(t, id))
                continue;
            const addr = String(t.address || "").replace(/^address:/i, "");
            if (!addr.length)
                continue;
            win.forceKillWindow(addr);
            n++;
        }
        return n;
    }
}
