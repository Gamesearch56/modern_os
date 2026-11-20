pragma Singleton

import Quickshell
import QtQuick
import "../Commons"

// Choosing a file or folder stays in this file manager.
// kind is "image", "file", or "folder". who tells the caller apart.
Singleton {
    id: root

    property bool active: false
    property string kind: "image"
    property string who: ""

    signal chosen(string path, string who)
    signal cancelled(string who)

    readonly property string headingKey: root.kind === "folder" ? "files.pick.folderTitle" : (root.kind === "file" ? "files.pick.fileTitle" : "files.pick.title")
    readonly property string useKey: root.kind === "folder" ? "files.pick.useFolder" : (root.kind === "file" ? "files.pick.useFile" : "files.pick.use")
    readonly property bool ready: {
        if (!root.active)
            return false;
        if (root.kind === "folder")
            return Files.place === "folder" && String(Files.path || "").charAt(0) === "/";
        const path = root._selected();
        return path.length > 0 && !root._dir(path) && (root.kind !== "image" || root._image(path));
    }

    function ask(folder: string, kind: string, who: string) {
        root.kind = String(kind || "image");
        root.who = String(who || "");
        root.active = true;
        Files.show(String(folder || ""));
    }

    function accept(path: string): bool {
        if (!root.active)
            return false;
        const explicit = String(path || "");
        let picked = explicit.length ? explicit : root._selected();
        if (root.kind === "folder") {
            if (explicit.length && !root._dir(explicit))
                return false;
            if (!root._dir(picked)) {
                if (Files.place !== "folder" || String(Files.path || "").charAt(0) !== "/")
                    return false;
                picked = String(Files.path);
            }
        } else if (!picked.length || root._dir(picked) || (root.kind === "image" && !root._image(picked)))
            return false;
        const who = root.who;
        root.who = "";
        root.active = false;
        root.chosen(picked, who);
        Files.hide();
        return true;
    }

    function _selected(): string {
        const rows = Files.selected || [];
        return rows.length === 1 ? String(rows[0] || "") : "";
    }

    function _dir(path: string): bool {
        const want = String(path || "");
        const lists = [Files.entries || [], FilesSearch.results || []];
        for (let n = 0; n < lists.length; n++) {
            const rows = lists[n];
            for (let i = 0; i < rows.length; i++) {
                if (String(rows[i].path || "") === want)
                    return rows[i].dir === true;
            }
        }
        return false;
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
            if (Files.open || !root.active)
                return;
            const who = root.who;
            root.who = "";
            root.active = false;
            root.cancelled(who);
        }
    }
}
