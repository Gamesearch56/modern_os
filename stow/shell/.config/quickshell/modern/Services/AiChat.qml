// Localhost Ollama /api/chat only. Body is a temp file (never argv).
// Caps, a 4-thread ceiling, and a UI throttle so a stream cannot stall
// qs/Hyprland. Thinking is off unless Settings turns it on, and then the
// reply cap grows so the thought does not consume the whole answer.
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

    property bool running: false
    property string thinking: ""
    property string content: ""
    property string lastError: ""
    property string phase: ""
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
        root.phase = "";
        root.lastError = "";
        root._dirty = false;
        const think = Config.accounts?.ai?.thinking === true;
        const brief = Config.accounts?.ai?.brief !== false;
        const clipped = root._clipMessages(messages);
        try {
            root._body = JSON.stringify({
                model: safe,
                messages: clipped,
                stream: true,
                think: think,
                options: {
                    num_thread: 4,
                    num_ctx: root._ctx(clipped, think),
                    // Thinking spends the budget before the answer. Leave
                    // room for the reply or the bubble stays empty.
                    num_predict: brief ? (think ? root.maxPredict * 3 : root.maxPredict) : root.maxPredict * 4
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
        root.phase = "";
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
        const brief = Config.accounts?.ai?.brief !== false;
        const out = [{ role: "system", content: I18n.t(brief ? "ai.systemBrief" : "ai.systemRoom") }];
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

    // Short chats stay on the small window. A long thread needs more
    // room or the runner rejects it and the bubble has no reason.
    function _ctx(messages: var, think: bool): int {
        let chars = 0;
        const list = messages || [];
        for (let i = 0; i < list.length; i++)
            chars += String(list[i] && list[i].content || "").length;
        const fit = Math.ceil(chars / 3) + 512;
        return Math.max(think ? 4096 : 2048, Math.min(8192, fit));
    }

    function _explain(code: string): string {
        switch (String(code || "")) {
        case "offline": return I18n.t("ai.errorOffline");
        case "timeout": return I18n.t("ai.timeout");
        case "memory": return I18n.t("ai.errorMemory");
        case "context": return I18n.t("ai.errorContext");
        case "model": return I18n.t("ai.errorModel");
        case "empty": return I18n.t("ai.errorEmpty");
        default: return I18n.t("ai.errorRefused");
        }
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
            proc.command = [Paths.script("ollama-chat.sh"), req.path];
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
            root.lastError = root._explain(String(data.error));
            return;
        }
        if (data.status === "search") {
            root.phase = "search";
            root.chunk(root.content, root.thinking);
            return;
        }
        const msg = data.message || ({});
        if (msg.thinking)
            root.thinking += String(msg.thinking).replace(/\0/g, "");
        if (msg.content) {
            root.phase = "";
            root.content += String(msg.content).replace(/\0/g, "");
        }
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
                root.lastError = I18n.t("ai.errorRefused");
            root._finish(code === 0, root.lastError);
        }
    }
}
