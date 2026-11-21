pragma Singleton

import Quickshell
import QtQuick
import "../Commons"

// Choosing a file or folder stays in this file manager.
// kind is "image", "media" (video or audio), "file", "folder", or "save"
// (a folder plus a new name, see FilesSaveAs). who tells the caller apart.
// askFor() options: multiple (several files at once) and patterns (globs
// that replace the kind's own extension list).
Singleton {
    id: root

    property bool active: false
    property string kind: "image"
    property string who: ""
    property bool multiple: false
    property var patterns: []

    signal chosen(string path, string who)
    signal chosenAll(var paths, string who)
    signal cancelled(string who)

    readonly property var _keys: ({
        image: ["files.pick.title", "files.pick.use"],
        media: ["files.pick.mediaTitle", "files.pick.useMedia"],
        file: ["files.pick.fileTitle", "files.pick.useFile"],
        folder: ["files.pick.folderTitle", "files.pick.useFolder"],
        save: ["files.pick.saveTitle", "files.pick.useSave"]
    })
    readonly property var _kindKeys: root.kind === "file" && root.multiple
        ? ["files.pick.filesTitle", "files.pick.useFiles"] : (root._keys[root.kind] || root._keys.image)
    readonly property string headingKey: root._kindKeys[0]
    readonly property string useKey: root._kindKeys[1]
    readonly property bool _inFolder: Files.place === "folder" && String(Files.path || "").charAt(0) === "/"
    readonly property bool ready: {
        if (!root.active)
            return false;
        if (root.kind === "folder")
            return root._inFolder;
        if (root.kind === "save")
            return root._inFolder && FilesSaveAs.valid;
        return root._picks().length > 0;
    }

    function ask(folder: string, kind: string, who: string) {
        root.askFor(folder, kind, who, ({}));
    }

    function askFor(folder: string, kind: string, who: string, opts: var) {
        const o = opts || {};
        root.kind = String(kind || "image");
        root.who = String(who || "");
        root.multiple = o.multiple === true && root.kind !== "folder" && root.kind !== "save";
        root.patterns = (o.patterns || []).map(p => String(p || "")).filter(p => p.length > 0);
        FilesSaveAs.reset(root.kind === "save" ? String(o.name || "") : "");
        root.active = true;
        Files.show(String(folder || ""), true);
    }

    function accept(path: string): bool {
        if (!root.active)
            return false;
        const explicit = String(path || "");
        if (root.kind === "save") {
            if (explicit.length && root._dir(explicit))
                return false;
            if (explicit.length)
                FilesSaveAs.name = explicit.slice(explicit.lastIndexOf("/") + 1);
            if (root.ready)
                FilesSaveAs.submit(String(Files.path));
            return true;
        }
        if (root.kind === "folder") {
            if (explicit.length && !root._dir(explicit))
                return false;
            let folder = explicit.length ? explicit : root._selected();
            if (!root._dir(folder)) {
                if (!root._inFolder)
                    return false;
                folder = String(Files.path);
            }
            root.finish([folder]);
            return true;
        }
        const picked = explicit.length ? [explicit] : root._picks();
        if (!picked.length || picked.some(p => root._dir(p) || !root._fits(p)))
            return false;
        root.finish(picked);
        return true;
    }

    function finish(paths: var) {
        const who = root.who;
        root.who = "";
        root.active = false;
        root.chosenAll(paths, who);
        root.chosen(String(paths[0] || ""), who);
        Files.hide();
    }

    function _picks(): var {
        const rows = (Files.selected || []).map(p => String(p || "")).filter(p => p.length > 0);
        if (!rows.length || (!root.multiple && rows.length > 1))
            return [];
        return rows.some(p => root._dir(p) || !root._fits(p)) ? [] : rows;
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
    readonly property var _globs: root.patterns.map(p => root._globRegex(p))

    function _fits(path: string): bool {
        const n = String(path || "");
        const leaf = n.slice(n.lastIndexOf("/") + 1);
        if (root._globs.length)
            return root._globs.some(re => re.test(leaf));
        const ok = root._extensions[root.kind];
        if (!ok)
            return true;
        const lower = leaf.toLowerCase();
        const dot = lower.lastIndexOf(".");
        return dot >= 0 && ok.indexOf(lower.slice(dot)) >= 0;
    }

    // Apps send shell globs ("*.png", "*.[jJ][pP][gG]"); matching ignores case like other choosers.
    function _globRegex(glob: string): var {
        let out = "";
        for (let i = 0; i < glob.length; i++) {
            const c = glob.charAt(i);
            if (c === "*") out += ".*";
            else if (c === "?") out += ".";
            else if (c === "[") {
                const end = glob.indexOf("]", i + 1);
                if (end < 0) { out += "\\["; continue; }
                out += "[" + glob.slice(i + 1, end).replace(/\\/g, "\\\\") + "]";
                i = end;
            } else out += c.replace(/[.+^${}()|\\\/]/g, "\\$&");
        }
        return new RegExp("^" + out + "$", "i");
    }

    Connections {
        target: Files
        function onOpenChanged() {
            if (Files.open || !root.active)
                return;
            const who = root.who;
            root.who = "";
            root.active = false;
            FilesSaveAs.reset("");
            root.cancelled(who);
        }
        function onSelectedChanged() {
            if (!root.active || root.kind !== "save")
                return;
            const one = root._selected();
            if (one.length && !root._dir(one))
                FilesSaveAs.name = one.slice(one.lastIndexOf("/") + 1);
        }
    }
}
