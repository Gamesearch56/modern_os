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
        titleKey: "settings.fields.protonWayland"
        MSwitch {
            checked: !!(Config.gaming?.protonWayland)
            onToggled: (v) => ConfigWrite.set("gaming.protonWayland", v)
        }
    }
    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.hdrSession"
        MSwitch {
            checked: !!(Config.gaming?.hdrSession)
            onToggled: (v) => ConfigWrite.set("gaming.hdrSession", v)
        }
    }
    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.vmMaxMapCount"
        MSwitch {
            checked: !!(Config.gaming?.systemFixes?.vmMaxMapCount)
            onToggled: (v) => ConfigWrite.set("gaming.systemFixes.vmMaxMapCount", v)
        }
    }
    MHint { key: "settings.hints.gamingGated"; Layout.fillWidth: true }
}
