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

    function place(op: string, dest: string, sources: var) {
        const list = [];
        const rows = sources || [];
        for (let i = 0; i < rows.length; i++) {
            if (rows[i])
                list.push(String(rows[i]));
        }
        if (!list.length || dest.charAt(0) !== "/" || root.open || proc.running)
            return;
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

    function choose(mode: string) {
        if (!root.open)
            return;
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
        const hit = root._hits[root._at] || ({});
        root._remember(String(hit.src || ""), { mode: "name", name: String(text || "").trim() });
        Files.naming = false;
        root._at += 1;
        root._show();
    }

    function abort() {
        root.open = false;
        root._hits = [];
        Files.naming = false;
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
