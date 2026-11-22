pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

// A file request from another app. scripts/file-chooser-portal.py starts
// files-window.qml with MODERN_FILE_CHOOSE (what to choose) and reads
// MODERN_FILE_CHOOSE_OUT once the window has closed. Closing without a
// choice writes nothing, which the portal answers as cancelled.
Singleton {
    id: root

    readonly property var spec: root._parse(Quickshell.env("MODERN_FILE_CHOOSE") || "")
    readonly property bool active: root.spec !== null
    // [{ name, patterns }] as the app named them; the names are the app's own labels.
    property var filters: []
    property int filterIndex: 0

    function begin(): bool {
        if (!root.active)
            return false;
        const s = root.spec;
        root.filters = (s.filters || []).map(f => ({
            name: String(f.name || ""),
            patterns: (f.patterns || []).map(p => String(p || ""))
        }));
        const at = Number(s.filter);
        root.filterIndex = at >= 0 && at < root.filters.length ? at : 0;
        const kind = s.mode === "save" ? "save" : s.mode === "folder" ? "folder" : "file";
        FilesChoose.askFor(String(s.folder || ""), kind, "portal", {
            multiple: s.multiple === true,
            patterns: root._patterns(root.filterIndex),
            name: String(s.name || "")
        });
        return true;
    }

    function useFilter(at: int) {
        if (at < 0 || at >= root.filters.length)
            return;
        root.filterIndex = at;
        FilesChoose.patterns = root._patterns(at);
    }

    function _patterns(at: int): var {
        const f = root.filters[at];
        const list = f ? f.patterns : [];
        return list.indexOf("*") >= 0 ? [] : list;
    }

    function _parse(text: string): var {
        if (!text.length)
            return null;
        try {
            const s = JSON.parse(text);
            return s && typeof s === "object" ? s : null;
        } catch (e) {
            Logger.warn("FilesRequest", "unreadable request");
            return null;
        }
    }

    Connections {
        target: FilesChoose
        function onChosenAll(paths, who) {
            if (who !== "portal" || !root.active)
                return;
            answer.setText(JSON.stringify({ paths: paths, filter: root.filterIndex }));
        }
    }

    FileView {
        id: answer
        path: Quickshell.env("MODERN_FILE_CHOOSE_OUT") || ""
        blockWrites: true
        atomicWrites: true
        printErrors: false
    }
}
