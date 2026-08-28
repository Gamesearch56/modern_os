// Markdown notes under ~/.local/share/modern/notes. Process `ls` for
// the list; CRUD goes through execDetached / FileView so Modules only
// bind Notes.list.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string dir: `${root.home}/.local/share/modern/notes`
    property var list: []
    property string activeName: ""
    property string activeText: ""

    Process {
        id: lister
        command: ["sh", "-c", "mkdir -p \"$HOME/.local/share/modern/notes\" && ls -1 \"$HOME/.local/share/modern/notes\" | grep -E '\\.md$' || true"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.list = this.text.trim().split("\n").filter(s => s.length > 0);
            }
        }
    }

    FileView {
        id: body
        path: root.activeName.length > 0 ? `${root.dir}/${root.activeName}` : ""
        printErrors: false
        onLoaded: root.activeText = text()
        onLoadFailed: root.activeText = ""
    }

    function refresh() {
        lister.running = true;
    }

    function _safe(name: string): string {
        const base = (name || "note.md").split("/").pop();
        return base.indexOf("..") >= 0 ? "" : base;
    }

    function openNote(name: string) {
        root.activeName = root._safe(name);
    }

    function create(name: string) {
        let n = root._safe(name);
        if (!n)
            return;
        if (!n.endsWith(".md"))
            n = n + ".md";
        Quickshell.execDetached(["sh", "-c", `mkdir -p '${root.dir}' && : >> '${root.dir}/${n}'`]);
        root.refresh();
    }

    function removeNote(name: string) {
        const n = root._safe(name);
        if (!n)
            return;
        Quickshell.execDetached(["rm", "-f", `${root.dir}/${n}`]);
        if (root.activeName === n)
            root.activeName = "";
        root.refresh();
    }

    function save(text: string) {
        if (!root.activeName)
            return;
        body.setText(text);
        root.activeText = text;
    }
}
