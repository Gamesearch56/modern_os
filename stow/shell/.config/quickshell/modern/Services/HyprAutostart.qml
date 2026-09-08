// Close of general.autostart apps hides them on special:background.
import QtQuick
import "../Commons"

QtObject {
    id: root

    property var windows: null

    function isAutostartWindow(toplevel: var): bool {
        const list = Config.general.autostart || [];
        const win = root.windows;
        if (!win || !toplevel || list.length === 0)
            return false;
        const fields = win._classFields(toplevel);
        let raw = "";
        for (let i = 0; i < fields.length; i++) {
            const s = String(fields[i] || "");
            if (s.length) {
                raw = s;
                break;
            }
        }
        const vivaldiApp = /^vivaldi-/i.test(raw) && raw.indexOf("__-Default") !== -1;
        for (let j = 0; j < list.length; j++) {
            const needle = win._normId(String(list[j] || ""));
            if (!needle.length)
                continue;
            for (let k = 0; k < fields.length; k++) {
                const n = win._normId(String(fields[k] || ""));
                if (!n.length)
                    continue;
                if (vivaldiApp) {
                    if (n.indexOf(needle) !== -1)
                        return true;
                    if (needle.indexOf("mail") !== -1 && n.indexOf("mailproton") !== -1)
                        return true;
                    if (needle.indexOf("calendar") !== -1 && n.indexOf("calendarproton") !== -1)
                        return true;
                } else if (n === needle || (needle.length >= 5 && n.indexOf(needle) !== -1)
                    || (n.length >= 5 && needle.indexOf(n) !== -1)) {
                    return true;
                }
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
        if (onBg && win.host && win.host._lua)
            win.host.dispatch("hl.dsp.workspace.toggle_special(\"background\")");
        return true;
    }
}
