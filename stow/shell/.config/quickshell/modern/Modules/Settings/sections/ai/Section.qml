import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    id: root
    spacing: Tokens.spacing.lg

    property bool _didDefault: false

    readonly property string provider: Config.accounts?.ai?.provider ?? "none"
    readonly property bool ollamaOn: root.provider === "ollama"
    readonly property bool geminiOn: root.provider === "gemini"
    readonly property string modelId: String(Config.accounts?.ai?.ollamaModel || "").replace(/:latest$/, "")
    readonly property string geminiModel: String(Config.accounts?.ai?.geminiModel || "")

    function _defaultOff() {
        if (root._didDefault || !Ai.probed || Ai.ready)
            return;
        if (root.provider !== "ollama")
            return;
        root._didDefault = true;
        ConfigWrite.set("accounts.ai.provider", "none");
    }

    Component.onCompleted: {
        Ai.watching = true;
        Ai.refreshStatus();
    }
    Component.onDestruction: Ai.watching = false

    Connections {
        target: Ai
        function onProbedChanged() { root._defaultOff(); }
        function onReadyChanged() { root._defaultOff(); }
    }

    MField {
        labelKey: "settings.fields.aiProvider"
        MSegmented {
            value: root.provider
            model: [
                { value: "ollama", titleKey: "settings.aiOllama" },
                { value: "gemini", titleKey: "settings.aiGemini" },
                { value: "none", titleKey: "settings.aiNone" }
            ]
            onSelected: (v) => ConfigWrite.set("accounts.ai.provider", v)
        }
    }

    MField {
        visible: root.ollamaOn
        labelKey: "settings.fields.aiModel"
        MSelect {
            enabled: Ai.running
            placeholderKey: "settings.ollama.noModels"
            model: {
                void Ai.models;
                void Config.accounts?.ai?.ollamaModel;
                return Ai.modelChoices();
            }
            value: root.modelId
            onSelected: (v) => ConfigWrite.set("accounts.ai.ollamaModel", v)
        }
    }

    Gemini {
        visible: root.geminiOn
        Layout.fillWidth: true
    }

    MField {
        visible: root.geminiOn
        labelKey: "settings.fields.aiModel"
        hintKey: "settings.hints.geminiModel"
        Layout.topMargin: Tokens.spacing.xxl
        MSelect {
            enabled: Ai.geminiHasKey
            placeholderKey: "settings.gemini.noModels"
            model: {
                void Ai.geminiModels;
                void Config.accounts?.ai?.geminiModel;
                return Ai.geminiModelChoices();
            }
            value: root.geminiModel
            onSelected: (v) => ConfigWrite.set("accounts.ai.geminiModel", v)
        }
    }

    Install {
        id: ollamaSetup
        visible: root.ollamaOn && (!Ai.ready || ollamaSetup.setupBusy || (Ai.models || []).length === 0)
        Layout.fillWidth: true
    }
}
