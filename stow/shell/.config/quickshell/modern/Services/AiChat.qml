// Streams POST /api/chat. Ai.qml owns history; this Item owns curl.
// `think: true` 400s on models without a thinking capability — retry once.
import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Item {
    id: root

    property bool running: false
    property string thinking: ""
    property string content: ""
    property string lastError: ""
    property string _body: ""
    property bool _droppedThink: false
    property bool _restarting: false

    signal chunk(string content, string thinking)
    signal finished(bool ok, string error)

    function start(body: string) {
        root._droppedThink = false;
        root._restarting = false;
        root._body = body;
        root.thinking = "";
        root.content = "";
        root.lastError = "";
        if (proc.running) {
            root._restarting = true;
            proc.running = false;
            return;
        }
        root._launch();
    }

    function stop() {
        root._restarting = false;
        if (proc.running)
            proc.running = false;
        root.running = false;
    }

    function _launch() {
        root.running = true;
        proc.command = [
            "curl", "-sS", "-N", "--max-time", "180",
            "-H", "Content-Type: application/json",
            "--data-binary", root._body,
            "http://127.0.0.1:11434/api/chat"
        ];
        proc.running = true;
    }

    function _retryWithoutThink(): bool {
        if (root._droppedThink)
            return false;
        const e = String(root.lastError || "");
        if (e.indexOf("does not support thinking") === -1)
            return false;
        try {
            const data = JSON.parse(root._body);
            delete data.think;
            root._body = JSON.stringify(data);
        } catch (err) {
            return false;
        }
        root._droppedThink = true;
        root.lastError = "";
        root._launch();
        return true;
    }

    function _onLine(line: string) {
        const raw = String(line || "").trim();
        if (!raw.length)
            return;
        let data = null;
        try {
            data = JSON.parse(raw);
        } catch (e) {
            return;
        }
        if (data.error) {
            root.lastError = String(data.error);
            return;
        }
        const msg = data.message || ({});
        if (msg.thinking)
            root.thinking += String(msg.thinking);
        if (msg.content)
            root.content += String(msg.content);
        root.chunk(root.content, root.thinking);
        if (data.done)
            root._finish(true, "");
    }

    function _finish(ok: bool, err: string) {
        if (!root.running)
            return;
        root.running = false;
        const e = err || root.lastError;
        root.finished(ok && !e, e);
    }

    Process {
        id: proc
        running: false
        stdout: SplitParser {
            onRead: (line) => root._onLine(line)
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim();
                if (t.length > 0)
                    root.lastError = t.split("\n")[0];
            }
        }
        onExited: (code) => {
            if (root._restarting) {
                root._restarting = false;
                root._launch();
                return;
            }
            if (root._retryWithoutThink())
                return;
            if (code === 28) {
                root._finish(false, I18n.t("ai.timeout"));
                return;
            }
            if (code !== 0 && !root.lastError)
                root.lastError = I18n.t("ai.error");
            root._finish(code === 0, root.lastError);
        }
    }
}
