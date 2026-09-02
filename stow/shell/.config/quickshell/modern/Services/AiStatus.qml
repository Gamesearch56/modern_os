// Ollama presence + /api/tags. Ai.qml owns chat history.
import Quickshell.Io
import QtQuick
import "../Commons"

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

    function modelChoices(): var {
        const out = [];
        const seen = {};
        const list = (root.ai && root.ai.models) || [];
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

    function resolveModel(want: string): string {
        const w = String(want || "").replace(/:latest$/, "");
        const list = (root.ai && root.ai.models) || [];
        let family = "";
        for (let i = 0; i < list.length; i++) {
            const n = String(list[i] || "");
            if (!n.length)
                continue;
            const stem = n.replace(/:latest$/, "");
            if (stem === w || n === w || (w.length > 0 && n.indexOf(w + ":") === 0))
                return n;
            if (!family.length && w.length >= 3
                    && (stem.indexOf(w + ".") === 0 || stem.indexOf(w + "-") === 0))
                family = n;
        }
        return family;
    }

    function _parseStatus(text: string) {
        if (!root.ai)
            return;
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
        root.ai.running = on;
        root.ai.models = names;
        root.ai.probed = true;
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
            onStreamFinished: root._parseStatus(this.text)
        }
        onExited: (code) => {
            if (code !== 0)
                root._parseStatus("");
        }
    }
}
