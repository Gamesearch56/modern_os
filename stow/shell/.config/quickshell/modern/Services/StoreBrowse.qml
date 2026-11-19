// Extra official-repo pages for a category or search needle.
import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Item {
    id: root
    visible: false
    width: 0
    height: 0

    property bool hasMore: false
    property bool listEnd: false
    property bool loading: false
    property string _query: ""
    property bool _strict: false
    property int _limit: 24
    property var _pendingRows: []
    property bool _pendingDone: false
    property bool _havePage: false
    property bool _minOk: false
    signal page(var rows, bool done)

    Process {
        id: proc
        running: false
        stdout: StdioCollector { id: out }
        onExited: (code) => root._done(out.text)
    }

    Timer {
        id: hold
        interval: Motion.storePageMs
        repeat: false
        onTriggered: {
            root._minOk = true;
            root._flush();
        }
    }

    function reset(query: string, strict) {
        hold.stop();
        proc.running = false;
        root._query = String(query || "").trim();
        root._strict = strict === true;
        root.loading = false;
        root.listEnd = false;
        root._havePage = false;
        root._minOk = false;
        root.hasMore = root._query.length > 0;
    }

    function fetch(seen) {
        if (!root.hasMore || root.loading)
            return;
        const q = root._query;
        if (!q.length || q.indexOf("-") === 0)
            return;
        const argv = [Paths.script("pkg-browse.sh")];
        if (root._strict)
            argv.push("--strict");
        argv.push(q, String(root._limit));
        const names = seen || [];
        for (let i = 0; i < names.length && argv.length < 180; i++) {
            const n = String(names[i] || "");
            if (n.length)
                argv.push(n);
        }
        root._havePage = false;
        root._minOk = false;
        root.loading = true;
        hold.restart();
        proc.command = argv;
        proc.running = true;
    }

    function _done(text: string) {
        if (!root.loading)
            return;
        let rows = [];
        try {
            const parsed = JSON.parse(String(text || "").trim() || "[]");
            rows = Array.isArray(parsed) ? parsed : [];
        } catch (e) {
            rows = [];
        }
        root._pendingRows = rows;
        root._pendingDone = rows.length < root._limit;
        root._havePage = true;
        root._flush();
    }

    function _flush() {
        if (!root.loading || !root._minOk || !root._havePage)
            return;
        const rows = root._pendingRows;
        const done = root._pendingDone;
        root._havePage = false;
        hold.stop();
        root.loading = false;
        if (done) {
            root.hasMore = false;
            root.listEnd = true;
        }
        root.page(rows, done);
    }
}
