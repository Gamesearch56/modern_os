import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    spacing: Tokens.spacing.md

    MSectionHeader { key: "settings.fields.aiProvider" }
    MSegmented {
        Layout.fillWidth: true
        value: Config.accounts?.ai?.provider ?? "ollama"
        model: [
            { value: "ollama", titleKey: "settings.aiOllama" },
            { value: "none", titleKey: "settings.aiNone" }
        ]
        onSelected: (v) => ConfigWrite.set("accounts.ai.provider", v)
    }
    MField {
        visible: (Config.accounts?.ai?.provider ?? "ollama") === "ollama"
        labelKey: "settings.fields.ollamaModel"
        hintKey: "settings.hints.ollamaSetup"
        MTextField {
            text: Config.accounts?.ai?.ollamaModel ?? "llama3"
            onAccepted: ConfigWrite.set("accounts.ai.ollamaModel", text)
        }
    }
    MHint { key: "settings.hints.ollamaSetup"; Layout.fillWidth: true }
}
