pragma Singleton

import Quickshell
import QtQuick
import "../Commons"

// Choosing a file or folder stays in this file manager.
// kind is "image", "media" (video or audio), "file", or "folder". who
// tells the caller apart.
Singleton {
    id: root

    property bool active: false
    property string kind: "image"
    property string who: ""

    signal chosen(string path, string who)
    signal cancelled(string who)

    readonly property var _keys: ({
        image: ["files.pick.title", "files.pick.use"],
        media: ["files.pick.mediaTitle", "files.pick.useMedia"],
        file: ["files.pick.fileTitle", "files.pick.useFile"],
        folder: ["files.pick.folderTitle", "files.pick.useFolder"]
    })
    readonly property var _kindKeys: root._keys[root.kind] || root._keys.image
    readonly property string headingKey: root._kindKeys[0]
    readonly property string useKey: root._kindKeys[1]
    readonly property bool ready: {
        if (!root.active)
            return false;
        if (root.kind === "folder")
            return Files.place === "folder" && String(Files.path || "").charAt(0) === "/";
        const path = root._selected();
        return path.length > 0 && !root._dir(path) && root._fits(path);
    }

    function ask(folder: string, kind: string, who: string) {
        root.kind = String(kind || "image");
        root.who = String(who || "");
        root.active = true;
        Files.show(String(folder || ""), true);
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
        } else if (!picked.length || root._dir(picked) || !root._fits(picked))
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

    readonly property var _extensions: ({
        image: [".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp", ".tif", ".tiff", ".avif", ".heic", ".heif", ".jxl"],
        media: [".mp4", ".m4v", ".mkv", ".webm", ".avi", ".mov", ".wmv", ".flv", ".mpg", ".mpeg", ".ts", ".m2ts",
            ".mts", ".ogv", ".3gp", ".mp3", ".flac", ".ogg", ".oga", ".opus", ".m4a", ".aac", ".wav", ".wma", ".mka"]
    })

    function _fits(path: string): bool {
        const ok = root._extensions[root.kind];
        if (!ok)
            return true;
        const n = String(path || "").toLowerCase();
        const dot = n.lastIndexOf(".");
        return dot >= 0 && ok.indexOf(n.slice(dot)) >= 0;
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
