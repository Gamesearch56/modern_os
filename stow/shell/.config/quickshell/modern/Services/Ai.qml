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
    property bool _awaiting: false
    property string _stdout: ""

    Process {
        id: proc
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._stdout = this.text
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim().length > 0) {
                    root.lastError = this.text.trim();
                    Logger.warn("Ai", root.lastError);
                }
            }
        }
        onExited: Qt.callLater(() => root._onReply(root._stdout))
    }

    function chat(text: string) {
        const q = (text || "").trim();
        if (!q || root.busy)
            return;
        if ((Config.accounts?.ai?.provider ?? "ollama") === "none")
            return;
        try {
            root.history = root.history.concat([{ role: "user", text: q }]);
            const model = Config.accounts?.ai?.ollamaModel ?? "llama3";
            root.busy = true;
            root._awaiting = true;
            root.lastError = "";
            root._stdout = "";
            proc.command = ["ollama", "run", model, q];
            proc.running = true;
        } catch (e) {
            root.busy = false;
            root._awaiting = false;
            Logger.error("Ai", String(e));
        }
    }

    function clear() {
        root.history = [];
        root.lastError = "";
    }

    function _onReply(text: string) {
        if (!root._awaiting)
            return;
        root._awaiting = false;
        root.busy = false;
        const reply = (text || "").trim();
        const out = reply.length > 0 ? reply : I18n.t("ai.error");
        if (reply.length === 0 && root.lastError.length > 0)
            Logger.error("Ai", root.lastError);
        root.history = root.history.concat([{ role: "assistant", text: out }]);
    }
}
