// Gemini streaming chat. Account/key/models live in AiGeminiAccount.
import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Item {
    id: root

    property alias hasKey: account.hasKey
    property alias ready: account.ready
    property alias models: account.models

    property bool running: false
    property string content: ""
    property string thinking: ""
    property string lastError: ""
    property string signature: ""
    property string _model: ""
    property string _body: ""
    property bool _restarting: false
    property bool _capped: false
    property bool _closed: false
    property bool _armed: false

    readonly property int maxPrompt: 2000
    readonly property int maxReply: 12000
    readonly property int maxLine: 8192
    readonly property int maxMsgs: 12

    signal chunk(string content, string thinking)
    signal finished(bool ok, string error)

    AiGeminiAccount { id: account }

    FileView {
        id: req
        path: Paths.runtimeHome + "/modern-gemini-request.json"
        watchChanges: false
        printErrors: false
        onSaved: root._spawn()
    }

    function probe() { account.probe(); }
    function setKey(raw: string) { account.setKey(raw); }
    function openStudio() { account.openStudio(); }
    function modelChoices(): var { return account.modelChoices(); }
    function resolveModel(want: string): string { return account.resolveModel(want); }

    function start(model: string, messages: var) {
        const safe = root._safeModel(model);
        if (!safe.length) {
            root.finished(false, I18n.t("ai.errorGeminiModel"));
            return;
        }
        root._model = safe;
        root._capped = false;
        root._restarting = false;
        root._closed = false;
        root.thinking = "";
        root.content = "";
        root.signature = "";
        root.lastError = "";
        try {
            root._body = JSON.stringify({
                contents: root._contents(messages),
                systemInstruction: { parts: [{ text: I18n.t("ai.systemBrief") }] },
                generationConfig: root._genConfig(safe)
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
        root._armed = false;
        root._restarting = false;
        root._closed = true;
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
                || (c >= 97 && c <= 122) || c === 46 || c === 95 || c === 45;
            if (!ok)
                return "";
        }
        return m;
    }

    function _genConfig(model: string): var {
        const cfg = { maxOutputTokens: 4096 };
        const n = String(model || "").toLowerCase();
        if (n.indexOf("gemini-3.7") === 0)
            cfg.thinkingConfig = { thinkingLevel: "LOW" };
        else if (n.indexOf("gemini-3") === 0)
            cfg.thinkingConfig = { thinkingLevel: "low" };
        else if (n.indexOf("gemini-2.5") === 0)
            cfg.thinkingConfig = { thinkingBudget: 0 };
        return cfg;
    }

    function _tidy(s: string): string {
        let t = String(s || "").replace(/\r/g, "");
        // One blank line between adjacent blocks (including list items) for readable markdown.
        t = t.replace(/([^\n])\n(?!\n)([^\n])/g, "$1\n\n$2");
        return t.replace(/\n{3,}/g, "\n\n");
    }

    function _contents(messages: var): var {
        const src = messages || [];
        const out = [];
        const start = Math.max(0, src.length - root.maxMsgs);
        for (let i = start; i < src.length; i++) {
            const r = src[i];
            if (!r)
                continue;
            const role = r.role === "user" ? "user" : "model";
            let t = String(r.content || r.text || "").replace(/\0/g, "").trim();
            if (t.length > root.maxPrompt)
                t = t.substring(0, root.maxPrompt);
            if (!t.length)
                continue;
            const sig = String(r.sig || "");
            if (role === "model" && String(root._model || "").toLowerCase().indexOf("gemini-3.7") === 0 && !sig.length)
                continue;
            const part = ({ text: t });
            if (sig.length)
                part.thoughtSignature = sig;
            out.push({ role: role, parts: [part] });
        }
        return out;
    }

    function _launch() {
        try {
            root._armed = true;
            root.running = true;
            req.setText(root._body);
        } catch (e) {
            root._armed = false;
            root.finished(false, I18n.t("ai.error"));
            return;
        }
        Qt.callLater(() => root._spawn());
    }

    function _spawn() {
        if (!root._armed || !root.running)
            return;
        root._armed = false;
        proc.command = [Paths.script("gemini-api.sh"), "chat", root._model, req.path];
        proc.running = true;
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
        if (data.e) {
            root.lastError = String(data.e).substring(0, 240);
            root._finish(false, root.lastError);
            if (proc.running)
                proc.running = false;
            return;
        }
        if (data.c) {
            if (data.s)
                root.signature = String(data.s);
            root.content = root._tidy(root.content + String(data.c).replace(/\0/g, ""));
            if (root.content.length > root.maxReply) {
                root.content = root.content.substring(0, root.maxReply);
                root._overflow();
                return;
            }
            root.chunk(root.content, root.thinking);
        }
        if (data.d)
            root._finish(!!String(root.content || "").trim(),
                String(root.content || "").trim().length ? "" : I18n.t("ai.errorEmpty"));
    }

    function _overflow() {
        root._capped = true;
        root._finish(true, "");
        if (proc.running)
            proc.running = false;
    }

    function _finish(ok: bool, err: string) {
        if (root._closed)
            return;
        root._closed = true;
        root.running = false;
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
            if (code === 2)
                root.lastError = I18n.t("ai.errorGeminiAuth");
            else if (code !== 0 && !root.lastError)
                root.lastError = I18n.t("ai.error");
            root._finish(code === 0, root.lastError);
        }
    }
}
