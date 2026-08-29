import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    spacing: Tokens.spacing.md

    MSectionHeader { key: "settings.fields.accounts" }
    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.protonDrive"
        MSwitch {
            checked: !!(Config.accounts?.protonDrive?.enabled)
            onToggled: (v) => ConfigWrite.set("accounts.protonDrive.enabled", v)
        }
    }
    MField {
        labelKey: "settings.fields.calendarIcs"
        MTextField {
            text: Config.accounts?.calendarIcsUrl ?? ""
            onAccepted: ConfigWrite.set("accounts.calendarIcsUrl", text)
        }
    }
    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.kdeconnectEnabled"
        MSwitch {
            checked: Config.kdeconnect.enabled
            onToggled: (v) => ConfigWrite.set("kdeconnect.enabled", v)
        }
    }

    MSectionHeader { key: "settings.fields.aiProvider" }
    RowLayout {
        spacing: Tokens.spacing.sm
        MChip {
            key: "settings.aiOllama"
            checked: (Config.accounts?.ai?.provider ?? "ollama") === "ollama"
            onClicked: ConfigWrite.set("accounts.ai.provider", "ollama")
        }
        MChip {
            key: "settings.aiNone"
            checked: (Config.accounts?.ai?.provider ?? "") === "none"
            onClicked: ConfigWrite.set("accounts.ai.provider", "none")
        }
    }
    MField {
        visible: (Config.accounts?.ai?.provider ?? "ollama") === "ollama"
        labelKey: "settings.fields.ollamaModel"
        hintKey: "settings.hints.ollamaModel"
        MTextField {
            text: Config.accounts?.ai?.ollamaModel ?? "llama3"
            onAccepted: ConfigWrite.set("accounts.ai.ollamaModel", text)
        }
    }
}
