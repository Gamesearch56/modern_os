// Gemini account: gitignored secrets.json (or GEMINI_API_KEY) and
// the model list from the Developer API. Chat stays in AiGemini.qml.
import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Item {
    id: root

    property bool hasKey: false
    property bool ready: false
    property var models: []
    property string lastError: ""
    property string block: ""
    property bool _fileHasKey: false

    FileView {
        id: secretsFile
        path: Paths.configHome + "/modern/secrets.json"
        watchChanges: true
        printErrors: false
        onLoaded: root._ingest(text())
        onLoadFailed: {
            root._fileHasKey = false;
            root._syncHasKey();
        }
    }

    function probe() {
        root._syncHasKey();
        if (!root.hasKey) {
            root.ready = false;
            root.models = [];
            return;
        }
        if (tagsProc.running)
            return;
        tagsProc.running = false;
        Qt.callLater(() => { tagsProc.running = true; });
    }

    function setKey(raw: string) {
        const k = String(raw || "").trim();
        let obj = ({});
        try {
            obj = JSON.parse(secretsFile.text() || "{}") || ({});
        } catch (e) {
            obj = ({});
        }
        if (!obj.gemini || typeof obj.gemini !== "object")
            obj.gemini = ({});
        if (k.length)
            obj.gemini.apiKey = k;
        else
            delete obj.gemini.apiKey;
        try {
            secretsFile.setText(JSON.stringify(obj, null, 2) + "\n");
        } catch (err) {
            Logger.error("Ai", "secrets write failed");
            return;
        }
        root._fileHasKey = k.length > 0;
        root.block = "";
        root._syncHasKey();
        root.probe();
    }

    function openStudio() {
        Quickshell.execDetached(["xdg-open", "https://aistudio.google.com/apikey"]);
    }

    function openBilling() {
        Quickshell.execDetached(["xdg-open", "https://aistudio.google.com/billing"]);
    }

    function note(code: string): string {
        if (code === "credits" || code === "spend")
            root.block = code;
        if (code === "credits")
            return I18n.t("ai.errorGeminiCredits");
        if (code === "spend")
            return I18n.t("ai.errorGeminiSpend");
        if (code === "rate")
            return I18n.t("ai.errorGeminiRate");
        if (code === "model")
            return I18n.t("ai.errorGeminiModel");
        if (code === "auth")
            return I18n.t("ai.errorGeminiAuth");
        return I18n.t("ai.error");
    }

    function modelChoices(): var {
        const out = [];
        const seen = ({});
        const list = root.models || [];
        for (let i = 0; i < list.length; i++) {
            const n = String(list[i] || "");
            if (!n.length || seen[n])
                continue;
            seen[n] = true;
            out.push({ value: n, titleValue: n });
        }
        return out;
    }

    function resolveModel(want: string): string {
        const w = String(want || "").trim();
        if (!w.length)
            return "";
        const list = root.models || [];
        for (let i = 0; i < list.length; i++) {
            if (String(list[i]) === w)
                return w;
        }
        return "";
    }

    function _syncHasKey() {
        const env = String(Quickshell.env("GEMINI_API_KEY") || "").trim();
        root.hasKey = root._fileHasKey || env.length > 0;
        if (!root.hasKey) {
            root.ready = false;
            root.models = [];
        }
    }

    function _ingest(raw: string) {
        let on = false;
        try {
            const data = JSON.parse(String(raw || "{}")) || ({});
            on = String((data.gemini && data.gemini.apiKey) || "").trim().length > 0;
        } catch (e) {
            on = false;
        }
        root._fileHasKey = on;
        root._syncHasKey();
        if (root.hasKey)
            root.probe();
    }

    function _modelRank(name: string): int {
        const n = String(name || "").toLowerCase();
        const m = n.match(/gemini-(\d+)(?:\.(\d+))?/);
        const major = m ? Number(m[1]) : 0;
        const minor = m && m[2] ? Number(m[2]) : 0;
        let kind = 1;
        if (n.indexOf("pro") !== -1)
            kind = 3;
        else if (n.indexOf("flash") !== -1)
            kind = 2;
        const stable = (n.indexOf("exp") !== -1 || n.indexOf("preview") !== -1) ? 0 : 1;
        return major * 10000 + minor * 100 + kind * 10 + stable;
    }

    function _parseModels(raw: string) {
        const names = [];
        try {
            const data = JSON.parse(String(raw || "{}"));
            if (data.error) {
                root.lastError = root.note(String(data.error));
                root.ready = false;
                root.models = [];
                return;
            }
            const list = data.models || [];
            for (let i = 0; i < list.length; i++) {
                const row = list[i] || ({});
                const methods = row.supportedGenerationMethods || [];
                let ok = methods.length === 0;
                for (let m = 0; m < methods.length; m++) {
                    if (String(methods[m]) === "generateContent")
                        ok = true;
                }
                if (!ok)
                    continue;
                let n = String(row.name || "").replace(/^models\//, "");
                if (!n.length || n.indexOf("gemini") !== 0)
                    continue;
                const low = n.toLowerCase();
                if (low.indexOf("embedding") !== -1 || low.indexOf("imagen") !== -1
                        || low.indexOf("-tts") !== -1 || low.indexOf("aqa") !== -1)
                    continue;
                names.push(n);
            }
        } catch (e) {
            Logger.warn("Ai", "gemini models parse failed");
        }
        names.sort((a, b) => root._modelRank(b) - root._modelRank(a) || b.localeCompare(a));
        root.models = names;
        root.ready = root.hasKey && names.length > 0;
        if (!names.length && root.hasKey)
            root.lastError = root.note("auth");
    }

    Process {
        id: tagsProc
        command: [Paths.script("gemini-api.sh"), "models"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parseModels(this.text)
        }
        onExited: (code) => {
            if (code === 2) {
                root.ready = false;
                root.models = [];
                return;
            }
            if (code !== 0 && !(root.models || []).length && !root.lastError) {
                root.ready = false;
                root.lastError = I18n.t("ai.errorGeminiAuth");
            }
        }
    }
}
