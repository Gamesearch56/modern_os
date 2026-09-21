// Close of general.autostart apps hides them on special:background.
import QtQuick
import "../Commons"

QtObject {
    id: root

    property var windows: null

    function _norm(s: string): string {
        return String(s || "").replace(/\.desktop$/i, "").toLowerCase().replace(/[\s._-]+/g, "");
    }

    function _vivaldiAppMatch(classn: string, needle: string): bool {
        if (classn.indexOf("vivaldi") !== 0)
            return false;
        if (classn.indexOf(needle) !== -1)
            return true;
        if (needle.indexOf("mail") !== -1 && classn.indexOf("mailproton") !== -1)
            return true;
        if (needle.indexOf("calendar") !== -1 && classn.indexOf("calendarproton") !== -1)
            return true;
        if (needle.indexOf("whatsapp") !== -1 && classn.indexOf("whatsapp") !== -1)
            return true;
        return false;
    }

    function _fields(toplevel: var): var {
        const win = root.windows;
        if (!win || !toplevel)
            return [];
        const ipc = toplevel.lastIpcObject || ({});
        return [
            ipc.class, ipc.initialClass, toplevel.class, toplevel.initialClass,
            ipc.title, toplevel.title, ipc.initialTitle, toplevel.initialTitle
        ];
    }

    function isAutostartWindow(toplevel: var): bool {
        const list = Config.general.autostart || [];
        if (!toplevel || list.length === 0)
            return false;
        const fields = root._fields(toplevel);
        for (let j = 0; j < list.length; j++) {
            const needle = root._norm(String(list[j] || ""));
            if (!needle.length)
                continue;
            for (let k = 0; k < fields.length; k++) {
                const n = root._norm(String(fields[k] || ""));
                if (!n.length)
                    continue;
                if (root._vivaldiAppMatch(n, needle))
                    return true;
                if (n === needle)
                    return true;
                if (needle.length >= 5 && n.indexOf(needle) !== -1)
                    return true;
                if (n.length >= 5 && needle.indexOf(n) !== -1)
                    return true;
            }
        }
        return false;
    }

    function hide(address: string): bool {
        const win = root.windows;
        if (!win)
            return false;
        const addr = String(address || "").replace(/^address:/i, "");
        if (!addr.length)
            return false;
        const t = win.toplevelByAddress(addr);
        if (!t || !root.isAutostartWindow(t))
            return false;
        const ipc = t.lastIpcObject || ({});
        const wsName = String(t.workspace?.name || ipc.workspace?.name || "");
        const onBg = wsName.indexOf("special:background") !== -1 || wsName === "background";
        win.moveToBackground(addr);
        // If the user was looking at special:background, tuck that workspace away.
        if (onBg && win.host && win.host._lua)
            win.host.dispatch("hl.dsp.workspace.toggle_special(\"background\")");
        return true;
    }
}