import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    spacing: Tokens.spacing.md

    MSectionHeader { key: "settings.fields.dnd" }
    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.on"
        MSwitch {
            checked: Config.general.dndSchedule.enabled
            onToggled: (v) => ConfigWrite.set("general.dndSchedule.enabled", v)
        }
    }
    MField {
        labelKey: "settings.fields.dndFrom"
        MTextField {
            text: Config.general.dndSchedule.from
            onAccepted: ConfigWrite.set("general.dndSchedule.from", text)
        }
    }
    MField {
        labelKey: "settings.fields.dndTo"
        MTextField {
            text: Config.general.dndSchedule.to
            onAccepted: ConfigWrite.set("general.dndSchedule.to", text)
        }
    }

    MSectionHeader { key: "settings.fields.kdeconnect" }
    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.kdeconnectEnabled"
        MSwitch {
            checked: Config.kdeconnect.enabled
            onToggled: (v) => ConfigWrite.set("kdeconnect.enabled", v)
        }
    }

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
}
