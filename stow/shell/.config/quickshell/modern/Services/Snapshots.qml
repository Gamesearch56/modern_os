// Snapper list/delete. Restore stays gated (docs/BACKUP.md).
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property var items: []
    property bool running: false
    property string step: ""
    property string log: ""

    Process {
        id: listProc
        command: ["sh", "-c", "snapper -c root list 2>/dev/null | awk -F'|' 'NR>2 {n=$1+0; if(n<1) next; gsub(/^[ \\t]+|[ \\t]+$/,\"\",$1); gsub(/^[ \\t]+|[ \\t]+$/,\"\",$4); gsub(/^[ \\t]+|[ \\t]+$/,\"\",$7); print $1 \"\\t\" $4 \"\\t\" $7}'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parseList(this.text)
        }
        onExited: root.running = false
    }

    Process {
        id: mutProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.log += this.text
        }
        stderr: StdioCollector {
            onStreamFinished: root.log += this.text
        }
        onExited: {
            root.running = false;
            root.step = "";
            root.refresh();
        }
    }

    function refresh() {
        listProc.running = true;
    }

    function remove(num: string) {
        if (!num || root.running)
            return;
        root.running = true;
        root.step = I18n.t("settings.snapshotDelete");
        root.log = "";
        mutProc.command = ["snapper", "-c", "root", "delete", String(num)];
        mutProc.running = true;
    }

    function _parseList(text: string) {
        const out = [];
        const lines = (text || "").trim().split("\n");
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            if (!line || line.length === 0)
                continue;
            const parts = line.split("\t");
            out.push({
                number: String(parts[0] || "").trim(),
                date: String(parts[1] || "").trim(),
                description: String(parts[2] || "").trim()
            });
        }
        root.items = out;
    }
}
