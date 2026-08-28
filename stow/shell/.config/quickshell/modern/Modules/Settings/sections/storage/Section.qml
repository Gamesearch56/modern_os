import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    spacing: Tokens.spacing.md

    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.snapper"
        MSwitch {
            checked: Config.backup.snapperEnabled
            onToggled: (v) => ConfigWrite.set("backup.snapperEnabled", v)
        }
    }
    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.restic"
        MSwitch {
            checked: Config.backup.resticEnabled
            onToggled: (v) => ConfigWrite.set("backup.resticEnabled", v)
        }
    }
    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.preUpdateSnapshot"
        MSwitch {
            checked: Config.backup.preUpdateSnapshot
            onToggled: (v) => ConfigWrite.set("backup.preUpdateSnapshot", v)
        }
    }
    MHint { key: "settings.hints.storageGated"; Layout.fillWidth: true }
}
