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

    readonly property bool on: (Config.accounts?.ai?.provider ?? "none") === "ollama"
    readonly property string modelId: String(Config.accounts?.ai?.ollamaModel || "").replace(/:latest$/, "")

    function _defaultOff() {
        if (root._didDefault || !Ai.probed || Ai.ready)
            return;
        root._didDefault = true;
        if ((Config.accounts?.ai?.provider ?? "none") !== "none")
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
            value: Config.accounts?.ai?.provider ?? "none"
            model: [
                { value: "ollama", titleKey: "settings.aiOllama" },
                { value: "none", titleKey: "settings.aiNone" }
            ]
            onSelected: (v) => ConfigWrite.set("accounts.ai.provider", v)
        }
    }

    MField {
        visible: root.on
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

    Install {
        visible: root.on && !Ai.ready
        Layout.fillWidth: true
    }
}
