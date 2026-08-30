// Ollama presence + /api/tags. Ai.qml owns chat history.
import Quickshell.Io
import QtQuick

Item {
    id: root

    property var ai: null

    function refresh() {
        if (!root.ai || whichProc.running || tagsProc.running || root.ai.busy)
            return;
        whichProc.running = false;
        Qt.callLater(() => {
            if (!root.ai.busy)
                whichProc.running = true;
        });
    }

    Process {
        id: whichProc
        command: ["ollama", "--version"]
        running: false
        onExited: (code) => {
            if (root.ai)
                root.ai.installed = code === 0;
            tagsProc.running = false;
            Qt.callLater(() => {
                tagsProc.running = true;
            });
        }
    }

    Process {
        id: tagsProc
        command: ["curl", "-sf", "--max-time", "1", "http://127.0.0.1:11434/api/tags"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.ai)
                    root.ai._parseStatus(this.text);
            }
        }
        onExited: (code) => {
            if (code !== 0 && root.ai)
                root.ai._parseStatus("");
        }
    }
}
