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
        const rawFile = String(secretsFile.text() || "").trim();
        let obj = ({});
        if (rawFile.length) {
            try {
                obj = JSON.parse(rawFile) || ({});
            } catch (e) {
                Logger.error("Ai", "secrets write failed");
                return;
            }
        }
        if (!obj.openai || typeof obj.openai !== "object")
            obj.openai = ({});
        if (k.length)
            obj.openai.apiKey = k;
        else
            delete obj.openai.apiKey;
        try {
            secretsFile.setText(JSON.stringify(obj, null, 2) + "\n");
        } catch (err) {
            Logger.error("Ai", "secrets write failed");
            return;
        }
        root._fileHasKey = k.length > 0;
        root._syncHasKey();
        root.probe();
    }

    function openKeys() {
        Quickshell.execDetached(["xdg-open", "https://platform.openai.com/api-keys"]);
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

    function _ingest(raw: string) {
        let on = false;
        try {
            const data = JSON.parse(String(raw || "{}")) || ({});
            on = String((data.openai && data.openai.apiKey) || "").trim().length > 0;
        } catch (e) {
            on = false;
        }
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
                root.lastError = I18n.t("ai.errorChatGptAuth");
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
            if (code !== 0 && !(root.models || []).length) {
                root.ready = false;
                root.lastError = I18n.t("ai.errorChatGptAuth");
            }
        }
    }
}
