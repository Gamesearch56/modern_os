// ChatGPT account: gitignored secrets.json (or OPENAI_API_KEY) and
// the model list from the OpenAI API. Chat stays in AiChatGpt.qml.
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

    Connections {
        target: Secrets
        function onStoreChanged() { root._ingest(); }
    }

    Component.onCompleted: root._ingest()

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
        if (Secrets.put("openai", { apiKey: raw }))
            root.block = "";
    }

    function openKeys() {
        Quickshell.execDetached(["xdg-open", "https://platform.openai.com/api-keys"]);
    }

    function openBilling() {
        Quickshell.execDetached(["xdg-open", "https://platform.openai.com/settings/organization/billing/"]);
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
        const env = String(Quickshell.env("OPENAI_API_KEY") || "").trim();
        root.hasKey = root._fileHasKey || env.length > 0;
        if (!root.hasKey) {
            root.ready = false;
            root.models = [];
        }
    }

    function _ingest() {
        const on = Secrets.value("openai", "apiKey").length > 0;
        root._fileHasKey = on;
        root._syncHasKey();
        if (root.hasKey)
            root.probe();
    }

    function _parseModels(raw: string) {
        const names = [];
        try {
            const data = JSON.parse(String(raw || "{}"));
            if (data.error) {
                root._note(String(data.error));
                root.ready = false;
                root.models = [];
                return;
            }
            const list = data.models || [];
            for (let i = 0; i < list.length; i++) {
                const n = String(list[i] || "");
                if (n.length)
                    names.push(n);
            }
        } catch (e) {
            Logger.warn("Ai", "chatgpt models parse failed");
        }
        root.models = names;
        root.ready = root.hasKey && names.length > 0;
        if (!names.length && root.hasKey)
            root._note("auth");
    }

    function _note(code: string) {
        if (code === "credits" || code === "spend")
            root.block = code;
        if (code === "credits")
            root.lastError = I18n.t("ai.errorChatGptCredits");
        else if (code === "spend")
            root.lastError = I18n.t("ai.errorChatGptSpend");
        else if (code === "rate")
            root.lastError = I18n.t("ai.errorChatGptRate");
        else if (code === "model")
            root.lastError = I18n.t("ai.errorChatGptModel");
        else
            root.lastError = I18n.t("ai.errorChatGptAuth");
    }

    Process {
        id: tagsProc
        command: [Paths.script("chatgpt-api.sh"), "models"]
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
                root.lastError = I18n.t("ai.errorChatGptAuth");
            }
        }
    }
}
