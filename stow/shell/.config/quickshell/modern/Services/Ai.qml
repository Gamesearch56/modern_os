// Local assistant via `ollama run` when that binary exists. chat(text)
// appends the user turn, then the model reply, onto history. Missing
// ollama fails soft (history still records the user line).
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property var history: []
    property bool busy: false
    property string lastError: ""

    Process {
        id: proc
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._onReply(this.text)
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim().length > 0)
                    root.lastError = this.text.trim();
            }
        }
    }

    function chat(text: string) {
        const q = (text || "").trim();
        if (!q || root.busy)
            return;
        root.history = root.history.concat([{ role: "user", text: q }]);
        const model = Config.accounts?.ai?.ollamaModel ?? "llama3";
        root.busy = true;
        root.lastError = "";
        proc.command = ["ollama", "run", model, q];
        proc.running = true;
    }

    function clear() {
        root.history = [];
        root.lastError = "";
    }

    function _onReply(text: string) {
        root.busy = false;
        const reply = text.trim();
        if (reply.length === 0) {
            root.history = root.history.concat([{ role: "assistant", text: root.lastError || "…" }]);
            return;
        }
        root.history = root.history.concat([{ role: "assistant", text: reply }]);
    }
}
