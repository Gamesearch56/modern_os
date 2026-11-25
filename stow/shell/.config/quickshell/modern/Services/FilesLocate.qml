pragma Singleton
// A path typed in the location field. Stat it so the suggestion list can
// offer the real file, and so Enter opens it instead of searching.
import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property string path: ""
    property string name: ""
    property bool dir: false
    property bool found: false
    property int gen: 0
    property string _want: ""
    property string _raw: ""
    property bool _go: false
    property bool _stopping: false

    function same(text: string): bool {
        return root.found && root._clean(text) === root.path;
    }

    function ask(text: string) {
        const next = root._clean(text);
        if (next === root._want && (!next.length || proc.running || root._stopping || root.found))
            return;
        if (next !== root._want)
            root._go = false;
        root._want = next;
        root.found = false;
        root.path = "";
        if (!next.length) {
            root.gen++;
            if (proc.running) {
                root._stopping = true;
                proc.running = false;
            }
            return;
        }
        root._arm();
    }

    // True when this field text is a real path and navigation was started.
    function open(text: string): bool {
        const next = root._clean(text);
        if (!next.length)
            return false;
        root._raw = String(text || "").trim();
        if (!(root.found && root.path === next))
            root.ask(text);
        if (root.found && root.path === next) {
            root._enter();
            return true;
        }
        if (root._want === next && (proc.running || root._stopping)) {
            root._go = true;
            return true;
        }
        return false;
    }

    function _arm() {
        if (root._stopping || !root._want.length)
            return;
        if (proc.running) {
            root._stopping = true;
            proc.running = false;
            return;
        }
        proc.command = [Paths.script("files-ops.sh"), "stat", root._want];
        proc.running = true;
    }

    function _enter() {
        FilesSearch.stop();
        const path = root.path;
        if (!path.length)
            return;
        if (root.dir) {
            Files.go(path, true);
            return;
        }
        const slash = path.lastIndexOf("/");
        Files.go(slash > 0 ? path.slice(0, slash) : "/", true, [path]);
    }

    function _clean(text: string): string {
        let path = String(text || "").trim();
        const home = String(Paths.home || "");
        if (path === "~")
            path = home;
        else if (path.indexOf("~/") === 0)
            path = home + path.slice(1);
        if (path.charAt(0) !== "/")
            return "";
        const parts = [];
        const bits = path.split("/");
        for (let i = 0; i < bits.length; i++) {
            const part = bits[i];
            if (!part.length || part === ".")
                continue;
            if (part === "..")
                return "";
            parts.push(part);
        }
        return parts.length ? "/" + parts.join("/") : "/";
    }

    function _done(code: int, text: string) {
        const go = root._go;
        root._go = false;
        let info = null;
        if (code === 0) {
            try { info = JSON.parse(String(text || "")); } catch (e) { info = null; }
        }
        if (info && String(info.path || "") === root._want) {
            root.path = String(info.path);
            root.name = String(info.name || "");
            root.dir = !!info.dir && !info.link;
            root.found = true;
            root.gen++;
            if (go)
                root._enter();
            return;
        }
        root.found = false;
        root.gen++;
        if (go)
            FilesSearch.start(Files.path, root._raw || root._want, Files.showHidden, true);
    }

    Process {
        id: proc
        running: false
        stdout: StdioCollector { id: outBuf }
        stderr: StdioCollector {}
        onExited: (code) => {
            if (root._stopping) {
                root._stopping = false;
                root._arm();
                return;
            }
            root._done(code, String(outBuf.text || ""));
        }
    }
}
