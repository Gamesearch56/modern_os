// Name search keeps the best matches and replaces the list as the walk
// finds better ones. Content search still uses grep. The process is
// killed when the query changes.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property bool active: false
    property bool page: false
    property bool popup: false
    property string mode: "names"
    // home, computer, or folder. A folder scope uses rootPath when set,
    // otherwise the folder that is open.
    property string scope: "home"
    property string rootPath: ""
    property string query: ""
    property var results: []
    readonly property bool running: proc.running

    signal dismiss()
    signal cleared()

    property var _batch: []
    property bool _fresh: false

    function start(folder: string, text: string, hidden: bool, showPage: bool) {
        root.query = String(text || "");
        root.results = [];
        root._batch = [];
        root._fresh = false;
        paint.stop();
        if (!root.query.length) {
            root.stop();
            return;
        }
        // The folder stays put while suggestions stream in. The body
        // becomes the search page only after the text itself is submitted.
        root.page = showPage === true;
        root.active = root.page;
        proc.running = false;
        const where = root._where(folder);
        proc.command = [
            Paths.script("files-search.sh"),
            root.mode,
            "--root", where,
            "--near", folder || where,
            "--scope", root.scope === "home" || root.scope === "computer" ? root.scope : "folder",
            "--query", root.query,
            "--hidden", hidden ? "1" : "0"
        ];
        proc.running = true;
    }

    function choose(scope: string, path: string, folder: string, hidden: bool) {
        const next = scope === "computer" || scope === "folder" ? scope : "home";
        root.scope = next;
        root.rootPath = next === "folder" ? String(path || "") : "";
        if (!root.query.length)
            return;
        root.start(folder, root.query, hidden, root.page);
    }

    function _where(folder: string): string {
        if (root.scope === "computer")
            return "/";
        if (root.scope === "folder") {
            const picked = String(root.rootPath || "");
            if (picked.charAt(0) === "/")
                return picked;
            if (String(folder || "").charAt(0) === "/")
                return folder;
        }
        return Paths.home;
    }

    function openPage() {
        if (!root.query.length)
            return;
        root.page = true;
        root.active = true;
    }

    function stop() {
        paint.stop();
        proc.running = false;
        root.page = false;
        root.active = false;
        root.query = "";
        root.results = [];
        root._batch = [];
        root._fresh = false;
    }

    function requestDismiss() {
        root.dismiss();
    }

    function requestClear() {
        root.stop();
        root.cleared();
    }

    function _push(line: string) {
        const text = String(line || "").trim();
        if (!text.length || !root.query.length)
            return;
        let row = null;
        try { row = JSON.parse(text); } catch (e) { return; }
        if (!row || (row.q && row.q !== root.query))
            return;
        if (Array.isArray(row.replace)) {
            root._batch = row.replace;
            root._fresh = true;
            if (!paint.running)
                paint.start();
            return;
        }
        if (!row.path)
            return;
        const bag = root._batch.slice();
        bag.push(row);
        root._batch = bag;
        root._fresh = false;
        if (!paint.running)
            paint.start();
    }

    function _flush() {
        if (root._fresh) {
            const next = root._batch;
            root._batch = [];
            root._fresh = false;
            root.results = next;
            root.active = root.page && root.query.length > 0;
            return;
        }
        if (!root._batch.length)
            return;
        const rows = (root.results || []).concat(root._batch);
        root._batch = [];
        root.results = rows;
        root.active = root.page && root.query.length > 0;
    }

    Timer {
        id: paint
        interval: Motion.shortMs
        onTriggered: root._flush()
    }

    Process {
        id: proc
        running: false
        stdout: SplitParser { onRead: line => root._push(line) }
        stderr: StdioCollector {
            id: errBuf
            onStreamFinished: {
                const text = String(this.text || "").trim();
                if (text.length)
                    Logger.warn("Files", text.split("\n")[0]);
            }
        }
        onExited: root._flush()
    }
}
