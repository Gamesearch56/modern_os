// Localhost Ollama /api/chat only. Body is a temp file (never argv).
// Caps, a 4-thread ceiling, and a UI throttle so a stream cannot stall
// qs/Hyprland. think:false so Qwen3 cannot spend num_predict on hidden
// chain-of-thought and return an empty bubble. A short predict cap plus
// the shared brief instruction keeps bar replies light.
import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Item {
    id: root

    readonly property int maxPrompt: 2000
    readonly property int maxReply: 12000
    readonly property int maxLine: 4096
    readonly property int maxMsgs: 12
    readonly property int maxPredict: 768
    readonly property int curlMaxSec: 180

    property bool running: false
    property string thinking: ""
    property string content: ""
    property string lastError: ""
    property string _body: ""
    property bool _restarting: false
    property bool _dirty: false
    property bool _capped: false

    signal chunk(string content, string thinking)
    signal finished(bool ok, string error)

    FileView {
        id: req
        path: Paths.runtimeHome + "/modern-ai-request.json"
        watchChanges: false
        printErrors: false
    }

    Timer {
        interval: 150
        running: root.running && root._dirty
        repeat: true
        onTriggered: {
            root._dirty = false;
            root.chunk(root.content, root.thinking);
        }
    }

    function start(model: string, messages: var) {
        const safe = root._safeModel(model);
        if (!safe.length) {
            root.finished(false, I18n.t("ai.errorModel"));
            return;
        }
        root._capped = false;
        root._restarting = false;
        root.thinking = "";
        root.content = "";
        root.lastError = "";
        root._dirty = false;
        try {
            root._body = JSON.stringify({
                model: safe,
                messages: root._clipMessages(messages),
                stream: true,
                think: false,
                options: {
                    num_thread: 4,
                    num_ctx: 2048,
                    num_predict: root.maxPredict
                }
            });
        } catch (e) {
            root.finished(false, I18n.t("ai.error"));
            return;
        }
        if (proc.running) {
            root._restarting = true;
            proc.running = false;
            return;
        }
        root._launch();
    }

    function stop() {
        root._restarting = false;
        root._dirty = false;
        if (proc.running)
            proc.running = false;
        root.running = false;
    }

    function _safeModel(s: string): string {
        const m = String(s || "");
        if (m.length < 1 || m.length > 96 || m.indexOf("..") !== -1)
            return "";
        for (let i = 0; i < m.length; i++) {
            const c = m.charCodeAt(i);
            const ok = (c >= 48 && c <= 57) || (c >= 65 && c <= 90)
                || (c >= 97 && c <= 122) || c === 46 || c === 95 || c === 58 || c === 45;
            if (!ok)
                return "";
        }
        return m;
    }

    function _clipMessages(messages: var): var {
        const src = messages || [];
        const out = [{ role: "system", content: I18n.t("ai.systemBrief") }];
        const start = Math.max(0, src.length - root.maxMsgs);
        for (let i = start; i < src.length; i++) {
            const r = src[i];
            if (!r)
                continue;
            const role = r.role === "user" ? "user" : "assistant";
            let t = String(r.content || r.text || "").replace(/\0/g, "").trim();
            if (t.length > root.maxPrompt)
                t = t.substring(0, root.maxPrompt);
            if (!t.length)
                continue;
            out.push({ role: role, content: t });
        }
        return out;
    }

    function _launch() {
        try {
            req.setText(root._body);
        } catch (e) {
            root.finished(false, I18n.t("ai.error"));
            return;
        }
        root.running = true;
        Qt.callLater(() => {
            if (!root.running)
                return;
            proc.command = [
                "curl", "-sS", "-N", "--noproxy", "*",
                "--connect-timeout", "5", "--max-time", String(root.curlMaxSec),
                "-H", "Content-Type: application/json",
                "--data-binary", "@" + req.path,
                "http://127.0.0.1:11434/api/chat"
            ];
            proc.running = true;
        });
    }

    function _onLine(line: string) {
        const raw = String(line || "");
        if (!raw.length)
            return;
        if (raw.length > root.maxLine) {
            root._overflow();
            return;
        }
        let data = null;
        try {
            data = JSON.parse(raw);
        } catch (e) {
            return;
        }
        if (data.error) {
            root.lastError = String(data.error).substring(0, 240);
            return;
        }
        const msg = data.message || ({});
        if (msg.thinking)
            root.thinking += String(msg.thinking).replace(/\0/g, "");
        if (msg.content)
            root.content += String(msg.content).replace(/\0/g, "");
        if (root.content.length > root.maxReply) {
            root.content = root.content.substring(0, root.maxReply);
            root._overflow();
            return;
        }
        root._dirty = true;
        if (data.done)
            root._finish(true, "");
    }

    function _overflow() {
        root._capped = true;
        root._finish(true, "");
        if (proc.running)
            proc.running = false;
    }

    function _finish(ok: bool, err: string) {
        if (!root.running)
            return;
        root.running = false;
        root._dirty = false;
        root.chunk(root.content, root.thinking);
        const e = err || root.lastError;
        root.finished((ok || root._capped) && !e, e);
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
                    root.lastError = t.split("\n")[0].substring(0, 240);
            }
        }
        onExited: (code) => {
            if (root._restarting) {
                root._restarting = false;
                root._launch();
                return;
            }
            if (root._capped) {
                root._finish(true, "");
                return;
            }
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
