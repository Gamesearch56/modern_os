pragma Singleton
// A move or copy stops when the destination already has that name.
import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property bool open: false
    property string name: ""
    property string suggest: ""
    property bool folder: false
    property string _op: ""
    property string _dest: ""
    property var _sources: []
    property var _hits: []
    property int _at: 0
    property var _modes: ({})
    property bool _create: false
    property bool _makeDir: false
    property bool _waitTrash: false

    function place(op: string, dest: string, sources: var) {
        const list = [];
        const rows = sources || [];
        for (let i = 0; i < rows.length; i++) {
            if (rows[i])
                list.push(String(rows[i]));
        }
        if (!list.length || dest.charAt(0) !== "/" || root.open || proc.running)
            return;
        root._create = false;
        root._waitTrash = false;
        root._op = op === "move" ? "move" : "copy";
        root._dest = dest;
        root._sources = list;
        root._hits = [];
        root._at = 0;
        root._modes = ({});
        proc.command = [Paths.script("files-ops.sh"), "conflicts", root._op, dest].concat(list);
        proc.running = true;
    }

    function done(cmd: var, raw: string) {
        if (String((cmd || [])[0] || "") !== "place")
            return;
        let plan = ({});
        let info = ({});
        try {
            plan = JSON.parse(String(cmd[1] || "{}"));
            info = JSON.parse(String(raw || "{}"));
        } catch (e) {
            return;
        }
        const replaced = (info && info.replaced) || [];
        if (replaced.length)
            FilesPlaces.drop(replaced);
        if (plan.op !== "move")
            return;
        const paths = (info && info.paths) || [];
        const items = plan.items || [];
        for (let i = 0; i < items.length; i++) {
            const src = String(items[i].src || "");
            const to = String(paths[i] || "");
            if (src && to && src !== to)
                FilesPlaces.renameOne(src, to);
        }
    }

    // A new file or folder used a name that is already in this folder.
    function taken(cmd: var): bool {
        const op = String((cmd || [])[0] || "");
        if ((op !== "mkdir" && op !== "touch") || root.open)
            return false;
        const parent = String((cmd || [])[1] || "");
        const name = String((cmd || [])[2] || "");
        if (parent.charAt(0) !== "/" || !name.length)
            return false;
        root._create = true;
        root._makeDir = op === "mkdir";
        root._waitTrash = false;
        root._op = "";
        root._hits = [];
        root._dest = parent;
        root.name = name;
        root.folder = root._existingDir(name);
        root.suggest = root._free(name);
        root.open = true;
        return true;
    }

    function choose(mode: string) {
        if (!root.open && !(root._create && mode === "cancel"))
            return;
        if (root._create) {
            root._createChoose(mode);
            return;
        }
        if (mode === "cancel") {
            root.open = false;
            root._hits = [];
            return;
        }
        const hit = root._hits[root._at] || ({});
        if (mode === "keep") {
            root.suggest = String(hit.suggest || ("(2) " + String(hit.name || "")));
            root.open = false;
            Files.namingKind = "place";
            Files.naming = true;
            return;
        }
        root._remember(String(hit.src || ""), { mode: "replace" });
        root._at += 1;
        root._show();
    }

    function named(text: string) {
        if (root._create) {
            const leaf = String(text || "").trim();
            const kind = root._makeDir ? "dir" : "file";
            root._create = false;
            Files.naming = false;
            if (leaf.length)
                Files.create(kind, leaf);
            return;
        }
        const hit = root._hits[root._at] || ({});
        root._remember(String(hit.src || ""), { mode: "name", name: String(text || "").trim() });
        Files.naming = false;
        root._at += 1;
        root._show();
    }

    function abort() {
        root.open = false;
        root._hits = [];
        root._create = false;
        root._waitTrash = false;
        Files.naming = false;
    }

    function _createChoose(mode: string) {
        if (mode === "cancel") {
            root.abort();
            return;
        }
        if (mode === "keep") {
            root.open = false;
            Files.namingKind = "place";
            Files.naming = true;
            return;
        }
        const dest = root._dest;
        const path = dest === "/" ? "/" + root.name : dest + "/" + root.name;
        root.open = false;
        root._waitTrash = true;
        FilesTrash.move([path]);
    }

    function _existingDir(name: string): bool {
        const rows = Files.entries || [];
        for (let i = 0; i < rows.length; i++) {
            if (String(rows[i].name || "") === name)
                return rows[i].dir === true;
        }
        return root._makeDir;
    }

    function _free(name: string): string {
        const used = {};
        const rows = Files.entries || [];
        for (let i = 0; i < rows.length; i++)
            used[String(rows[i].name || "")] = true;
        for (let n = 2; n < 1000; n++) {
            const cand = "(" + n + ") " + name;
            if (!used[cand])
                return cand;
        }
        return "(2) " + name;
    }

    function _remember(src: string, choice: var) {
        const modes = ({});
        const prev = root._modes || ({});
        const keys = Object.keys(prev);
        for (let i = 0; i < keys.length; i++)
            modes[keys[i]] = prev[keys[i]];
        modes[src] = choice;
        root._modes = modes;
    }

    function _show() {
        if (root._at >= root._hits.length) {
            root.open = false;
            root._commit();
            return;
        }
        const hit = root._hits[root._at];
        root.name = String(hit.name || "");
        root.folder = !!hit.dir;
        root.open = true;
    }

    function _commit() {
        const items = [];
        const modes = root._modes || ({});
        for (let i = 0; i < root._sources.length; i++) {
            const src = root._sources[i];
            const choice = modes[src] || ({});
            if (choice.mode === "replace")
                items.push({ src: src, mode: "replace" });
            else if (choice.mode === "name")
                items.push({ src: src, mode: "name", name: String(choice.name || "") });
            else
                items.push({ src: src, mode: "keep" });
        }
        if (root._op === "move") {
            Files.clipboard = [];
            Files.clipboardMode = "";
        }
        Files._enqueue(["place", JSON.stringify({ op: root._op, dest: root._dest, items: items })], "mutate");
    }

    Connections {
        target: FilesTrash
        function onChanged() {
            if (!root._waitTrash || !root._create)
                return;
            root._waitTrash = false;
            const kind = root._makeDir ? "dir" : "file";
            const name = root.name;
            root._create = false;
            Files.create(kind, name);
        }
        function onFailed() {
            if (!root._waitTrash)
                return;
            root._waitTrash = false;
            root._create = false;
        }
    }

    Process {
        id: proc
        running: false
        stdout: StdioCollector { id: outBuf }
        stderr: StdioCollector { id: errBuf }
        onExited: (code) => {
            if (code !== 0) {
                Files.failed(String(errBuf.text || "").trim() || "refused");
                return;
            }
            try { root._hits = JSON.parse(String(outBuf.text || "[]")); } catch (e) { root._hits = []; }
            if (!root._hits.length) {
                root._commit();
                return;
            }
            root._at = 0;
            root._show();
        }
    }
}
