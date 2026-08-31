// Local assistant via Ollama's HTTP chat API. History is the
// conversation (AiStore writes it to XDG state). AiChat owns curl so a
// hung `ollama run` cannot steal stdin. Missing daemon fails soft.
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
    property string hostScreenName: ""
    property string lastError: ""
    property bool installed: false
    property bool running: false
    property bool probed: false
    property bool watching: false
    property var models: []
    readonly property bool ready: root.installed && root.running

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
        onFinished: (ok, err) => root._end(ok, err)
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
    }

    function modelChoices(): var {
        const out = [];
        const seen = {};
        const list = root.models || [];
        for (let i = 0; i < list.length; i++) {
            const stem = String(list[i] || "").replace(/:latest$/, "");
            if (!stem.length || seen[stem])
                continue;
            seen[stem] = true;
            out.push({ value: stem, titleValue: stem });
        }
        const cur = String(Config.accounts?.ai?.ollamaModel || "").replace(/:latest$/, "");
        if (cur.length > 0 && !seen[cur])
            out.unshift({ value: cur, titleValue: cur });
        return out;
    }

    function _parseStatus(text: string) {
        const raw = String(text || "");
        const brace = raw.indexOf("{");
        let names = [];
        let on = false;
        if (brace !== -1) {
            try {
                const data = JSON.parse(raw.substring(brace));
                const list = data.models || [];
                on = true;
                for (let i = 0; i < list.length; i++) {
                    const n = String(list[i].name || list[i].model || "");
                    if (n.length)
                        names.push(n);
                }
            } catch (e) {
                Logger.warn("Ai", String(e));
            }
        }
        root.running = on;
        root.models = names;
        root.probed = true;
    }

    function toggle(screen: var) {
        const name = root._nameOf(screen);
        if (root.panelOpen && root.hostScreenName === name) {
            root.hide();
            return;
        }
        root.hostScreenName = name;
        root.panelOpen = true;
        root.watching = true;
        root.refreshStatus();
    }

    function toggleFocused() {
        root.toggle({ name: root._focusedScreenName() });
    }

    function showFocused() {
        root.hostScreenName = root._focusedScreenName();
        root.panelOpen = true;
        root.watching = true;
        root.refreshStatus();
    }

    function hide() {
        root.panelOpen = false;
        root.hostScreenName = "";
        root.watching = false;
    }

    function openOn(screen: var): bool {
        if (!root.panelOpen)
            return false;
        if (!root.hostScreenName)
            return true;
        const name = root._nameOf(screen);
        if (name && name === root.hostScreenName)
            return true;
        const mon = Hypr.monitorForScreen(screen);
        if (mon && String(mon.name) === root.hostScreenName)
            return true;
        return false;
    }

    function _nameOf(screen: var): string {
        if (screen && screen.name)
            return String(screen.name);
        return "";
    }

    function _focusedScreenName(): string {
        const hyprName = Hypr.focusedMonitorName();
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            const s = screens[i];
            if (!s)
                continue;
            if (hyprName && s.name && String(s.name) === hyprName)
                return String(s.name);
            const mon = Hypr.monitorForScreen(s);
            if (hyprName && mon && String(mon.name) === hyprName)
                return String(s.name || mon.name);
        }
        if (hyprName)
            return hyprName;
        if (screens.length > 0 && screens[0] && screens[0].name)
            return String(screens[0].name);
        return "";
    }

    function _resolveModel(): string {
        const want = String(Config.accounts?.ai?.ollamaModel || "").replace(/:latest$/, "");
        const list = root.models || [];
        let family = "";
        for (let i = 0; i < list.length; i++) {
            const n = String(list[i] || "");
            const stem = n.replace(/:latest$/, "");
            if (stem === want || n === want || (want.length > 0 && n.indexOf(want + ":") === 0))
                return n;
            if (!family.length && want.length >= 3
                    && (stem.indexOf(want + ".") === 0 || stem.indexOf(want + "-") === 0))
                family = n;
        }
        return family;
    }

    function chat(text: string) {
        const q = (text || "").trim();
        if (!q || root.busy)
            return;
        if ((Config.accounts?.ai?.provider ?? "none") === "none" || !root.ready)
            return;
        const model = root._resolveModel();
        if (!model.length) {
            root.history = root.history.concat([
                { role: "user", text: q },
                { role: "assistant", text: I18n.t("ai.errorModel"), thinking: "", streaming: false }
            ]);
            root.lastError = I18n.t("ai.errorModel");
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
            const body = JSON.stringify({
                model: model,
                messages: prior,
                stream: true,
                think: true
            });
            stream.start(body);
        } catch (e) {
            root.busy = false;
            Logger.error("Ai", String(e));
        }
    }

    function clear() {
        stream.stop();
        root.busy = false;
        root.history = [];
        root.lastError = "";
        store.save([]);
    }

    function _apiMessages(): var {
        const out = [];
        const list = root.history || [];
        const start = Math.max(0, list.length - 20);
        for (let i = start; i < list.length; i++) {
            const r = list[i];
            if (!r || r.streaming)
                continue;
            const role = r.role === "user" ? "user" : "assistant";
            const t = String(r.text || "").trim();
            if (!t.length)
                continue;
            out.push({ role: role, content: t });
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
        list[list.length - 1] = last;
        root.history = list;
    }

    function _end(ok: bool, err: string) {
        const text = stream.content;
        const thinking = stream.thinking;
        root.busy = false;
        if (!ok || !String(text || "").trim().length) {
            const msg = String(err || "").trim() || I18n.t("ai.errorEmpty");
            root.lastError = msg;
            root._patchTail(msg, thinking, false);
            store.save(root.history);
            return;
        }
        root.lastError = "";
        root._patchTail(root._collapse(text), thinking, false);
        store.save(root.history);
    }

    function _collapse(text: string): string {
        return String(text || "").replace(/\r/g, "").replace(/\n{3,}/g, "\n\n").trim();
    }
}
