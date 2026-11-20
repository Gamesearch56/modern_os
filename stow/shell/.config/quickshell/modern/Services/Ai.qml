// Local Ollama or Gemini Developer API. History is XDG state (AiStore).
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property var history: []
    property bool busy: false
    property bool panelOpen: false
    property bool coverFullscreen: false
    property string hostScreenName: ""
    property string lastError: ""
    property bool installed: false
    property bool running: false
    property bool probed: false
    property bool watching: false
    property var models: []
    readonly property string _provider: String(Config.accounts?.ai?.provider ?? "none")
    readonly property bool ready: {
        if (root._provider === "gemini")
            return gemini.ready;
        if (root._provider === "chatgpt")
            return chatgpt.ready;
        return root._provider === "ollama" && root.installed && root.running;
    }
    readonly property bool geminiHasKey: gemini.hasKey
    readonly property string geminiBlock: gemini.block
    readonly property var geminiModels: gemini.models
    readonly property bool chatgptHasKey: chatgpt.hasKey
    readonly property string chatgptBlock: chatgpt.block
    readonly property var chatgptModels: chatgpt.models
    signal cancelled(string text)

    IpcHandler {
        target: "ai"
        function toggle() { root.toggleFocused(); }
        function show() { root.showFocused(); }
        function hide() { root.hide(); }
    }

    AiStatus {
        id: status
        ai: root
    }

    AiChat {
        id: stream
        onChunk: (content, thinking) => root._patchTail(content, thinking, true)
        onFinished: (ok, err) => root._end(ok, err, stream.content)
    }

    AiFocus { id: focus }

    AiGemini {
        id: gemini
        onChunk: (content, thinking) => root._patchTail(content, thinking, true)
        onFinished: (ok, err) => root._end(ok, err, gemini.content)
    }

    AiChatGpt {
        id: chatgpt
        onChunk: (content, thinking) => root._patchTail(content, thinking, true)
        onFinished: (ok, err) => root._end(ok, err, chatgpt.content)
    }

    AiStore {
        id: store
        onRestored: (rows) => {
            if (root.busy || root.history.length > 0 || rows.length === 0)
                return;
            root.history = rows;
        }
    }

    Timer {
        interval: 4000
        running: root.watching && !root.busy
        repeat: true
        onTriggered: root.refreshStatus()
    }

    Component.onCompleted: root.refreshStatus()

    function refreshStatus() {
        status.refresh();
        const cloud = root._cloud();
        if (cloud && cloud.hasKey && !cloud.ready)
            cloud.probe();
    }

    function _cloud(): var {
        if (root._provider === "gemini")
            return gemini;
        if (root._provider === "chatgpt")
            return chatgpt;
        return null;
    }

    function setGeminiKey(raw: string) { gemini.setKey(raw); }
    function clearGeminiKey() { gemini.setKey(""); }
    function openGeminiStudio() { gemini.openStudio(); }
    function openGeminiBilling() { gemini.openBilling(); }
    function geminiModelChoices(): var { return gemini.modelChoices(); }
    function setChatGptKey(raw: string) { chatgpt.setKey(raw); }
    function clearChatGptKey() { chatgpt.setKey(""); }
    function openChatGptKeys() { chatgpt.openKeys(); }
    function openChatGptBilling() { chatgpt.openBilling(); }
    function chatgptModelChoices(): var { return chatgpt.modelChoices(); }

    function toggle(screen: var) {
        const name = focus.nameOf(screen);
        if (root.panelOpen && root.hostScreenName === name) {
            root.hide();
            return;
        }
        root._openOn(name);
    }

    function toggleFocused() { root.toggle({ name: focus.focused() }); }
    function showFocused() { root._openOn(focus.focused()); }

    function _openOn(name: string) {
        root.hostScreenName = name;
        root.coverFullscreen = Hypr.focusedFullscreen;
        root.panelOpen = true;
        root.watching = true;
        root.refreshStatus();
    }

    function modelChoices(): var { return status.modelChoices(); }

    function hide() {
        root.panelOpen = false;
        root.hostScreenName = "";
        root.coverFullscreen = false;
        root.watching = false;
    }

    function openOn(screen: var): bool {
        return focus.covers(screen, root.panelOpen, root.hostScreenName);
    }

    function chat(text: string) {
        const q = (text || "").replace(/\0/g, "").trim();
        if (!q || root.busy)
            return;
        if (q.length > stream.maxPrompt) {
            root.lastError = I18n.t("ai.errorTooLong");
            return;
        }
        if (root._provider === "none" || !root.ready)
            return;
        const cloud = root._cloud();
        const want = cloud
            ? cloud.selectedModel()
            : String(Config.accounts?.ai?.ollamaModel || "").trim();
        if (cloud && !want.length) {
            root.history = root.history.concat([
                { role: "user", text: q },
                { role: "assistant", text: I18n.t("ai.errorNoModel"), thinking: "", streaming: false }
            ]);
            root.lastError = I18n.t("ai.errorNoModel");
            store.save(root.history);
            return;
        }
        const model = cloud ? cloud.resolveModel(want) : status.resolveModel(want);
        const modelErr = cloud ? cloud.modelError() : I18n.t("ai.errorModel");
        if (!model.length) {
            root.history = root.history.concat([
                { role: "user", text: q },
                { role: "assistant", text: modelErr, thinking: "", streaming: false }
            ]);
            root.lastError = modelErr;
            store.save(root.history);
            return;
        }
        try {
            const prior = root._apiMessages();
            prior.push({ role: "user", content: q });
            root.history = root.history.concat([
                { role: "user", text: q },
                { role: "assistant", text: "", thinking: "", streaming: true }
            ]);
            root.busy = true;
            root.lastError = "";
            store.save(root.history);
            if (cloud)
                cloud.start(model, prior);
            else
                stream.start(model, prior);
        } catch (e) {
            root.busy = false;
            Logger.error("Ai", String(e));
        }
    }

    function cancel() {
        stream.stop();
        gemini.stop();
        chatgpt.stop();
        const live = !!(root.history.length && root.history[root.history.length - 1]
            && root.history[root.history.length - 1].streaming);
        if (!root.busy && !live)
            return;
        const list = (root.history || []).slice();
        if (list.length && list[list.length - 1] && list[list.length - 1].role !== "user")
            list.pop();
        let draft = "";
        if (list.length && list[list.length - 1] && list[list.length - 1].role === "user") {
            draft = String(list[list.length - 1].text || "");
            list.pop();
        }
        root.history = list;
        root.busy = false;
        root.lastError = "";
        store.save(list);
        root.cancelled(draft);
    }

    function clear() {
        stream.stop();
        gemini.stop();
        chatgpt.stop();
        root.busy = false;
        root.history = [];
        root.lastError = "";
        store.save([]);
    }

    function _apiMessages(): var {
        const out = [];
        const list = root.history || [];
        const start = Math.max(0, list.length - stream.maxMsgs);
        for (let i = start; i < list.length; i++) {
            const r = list[i];
            if (!r || r.streaming)
                continue;
            const role = r.role === "user" ? "user" : "assistant";
            let t = String(r.text || "").replace(/\0/g, "").trim();
            if (t.length > stream.maxPrompt)
                t = t.substring(0, stream.maxPrompt);
            if (!t.length)
                continue;
            out.push({ role: role, content: t, sig: String(r.sig || "") });
        }
        return out;
    }

    function _patchTail(content: string, thinking: string, streaming: bool) {
        const list = root.history.slice();
        if (list.length === 0)
            return;
        const last = Object.assign({}, list[list.length - 1]);
        last.text = content;
        last.thinking = thinking;
        last.streaming = streaming;
        if (root._provider === "gemini" && gemini.signature)
            last.sig = gemini.signature;
        list[list.length - 1] = last;
        root.history = list;
    }

    function _end(ok: bool, err: string, text: string) {
        const live = !!(root.history.length && root.history[root.history.length - 1]
            && root.history[root.history.length - 1].streaming);
        if (!root.busy && !live)
            return;
        root.busy = false;
        if (!ok || !String(text || "").trim().length) {
            const msg = String(err || "").trim() || I18n.t("ai.errorEmpty");
            root.lastError = msg;
            root._patchTail(msg, "", false);
            store.save(root.history);
            return;
        }
        root.lastError = "";
        root._patchTail(String(text || "").replace(/\r/g, "")
            .replace(/([^\n])\n(?!\n)([^\n])/g, "$1\n\n$2").replace(/\n{3,}/g, "\n\n").trim(), "", false);
        store.save(root.history);
    }
}
