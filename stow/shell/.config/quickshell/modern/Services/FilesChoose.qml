pragma Singleton

import Quickshell
import QtQuick
import "../Commons"

// Picture choice uses this file manager. A separate system dialog
// would not match the rest of the desktop.
Singleton {
    id: root

    property bool active: false

    signal chosen(string path)

    readonly property bool ready: {
        const rows = Files.selected || [];
        return rows.length === 1 && root._image(String(rows[0] || ""));
    }

    function ask(folder: string) {
        root.active = true;
        Files.show(String(folder || ""));
    }

    function accept(path: string): bool {
        const next = String(path || "");
        const rows = Files.selected || [];
        const picked = next.length ? next : (rows.length === 1 ? String(rows[0] || "") : "");
        if (!root.active || !root._image(picked))
            return false;
        root.active = false;
        root.chosen(picked);
        Files.hide();
        return true;
    }

    function _image(path: string): bool {
        const n = String(path || "").toLowerCase();
        const dot = n.lastIndexOf(".");
        if (dot < 0)
            return false;
        const ext = n.slice(dot);
        const ok = [".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp", ".tif", ".tiff", ".avif", ".heic", ".heif", ".jxl"];
        return ok.indexOf(ext) >= 0;
    }

    Connections {
        target: Files
        function onOpenChanged() {
            if (!Files.open)
                root.active = false;
        }
    }
}
