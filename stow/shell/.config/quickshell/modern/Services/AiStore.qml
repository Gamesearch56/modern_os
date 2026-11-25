// Conversation turns in XDG state. Streaming placeholders are dropped
// so a reload never restores a half-written assistant row.
import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Item {
    id: root

    property bool ready: false

    readonly property int keep: 24
    readonly property int maxText: 12000
    readonly property string path: Paths.stateHome + "/modern/ai-history.json"

    signal restored(var rows)

    property var _pending: null

    FileView {
        id: file
        path: root.path
        watchChanges: false
        printErrors: false
        onLoaded: root._ingest(text())
        onLoadFailed: {
            root.ready = true;
            root.restored([]);
            if (root._pending)
                root.flush();
        }
    }

    function save(history) {
        root._pending = history;
        if (root.ready)
            root.flush();
    }

    function flush() {
        const rows = root._serial(root._pending);
        root._pending = null;
        if (!root.ready)
            return;
        try {
            file.setText(JSON.stringify(rows));
        } catch (e) {
            Logger.warn("Ai", "history persist failed: " + e);
        }
    }

    function _ingest(raw) {
        const s = String(raw || "[]");
        if (s.length > 262144) {
            Logger.warn("Ai", "history too large, discarding");
            root.ready = true;
            root.restored([]);
            root.save([]);
            return;
        }
        let rows = [];
        try {
            const data = JSON.parse(s);
            if (Array.isArray(data))
                rows = root._serial(data);
        } catch (e) {
            Logger.warn("Ai", "history parse failed: " + e);
        }
        root.ready = true;
        root.restored(rows);
        if (root._pending)
            root.flush();
    }

    function _serial(history) {
        const out = [];
        const list = history || [];
        for (let i = 0; i < list.length; i++) {
            const r = list[i];
            if (!r || r.streaming)
                continue;
            const role = r.role === "user" ? "user" : "assistant";
            let text = String(r.text || "").replace(/\0/g, "");
            if (text.length > root.maxText)
                text = text.substring(0, root.maxText);
            if (!text.length)
                continue;
            const row = ({ role: role, text: text, thinking: "" });
            if (r.sig)
                row.sig = String(r.sig);
            out.push(row);
        }
        return out.slice(Math.max(0, out.length - root.keep));
    }
}
