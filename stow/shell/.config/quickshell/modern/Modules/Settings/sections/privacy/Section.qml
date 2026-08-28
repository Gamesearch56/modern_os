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
    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.mirrorNotifications"
        MSwitch {
            checked: Config.kdeconnect.mirrorNotifications
            onToggled: (v) => ConfigWrite.set("kdeconnect.mirrorNotifications", v)
        }
    }
    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.sharedClipboard"
        MSwitch {
            checked: Config.kdeconnect.sharedClipboard
            onToggled: (v) => ConfigWrite.set("kdeconnect.sharedClipboard", v)
        }
    }
}
