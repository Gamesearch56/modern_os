import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    spacing: Tokens.spacing.md
    Model { id: model }

    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.frecency"
        MSwitch {
            checked: model.frecencyEnabled
            onToggled: (v) => ConfigWrite.set("launcher.frecencyEnabled", v)
        }
    }
    MField {
        labelKey: "settings.fields.launcherResults"
        MSlider {
            from: 4
            to: 20
            value: model.resultCount
            onMoved: (v) => ConfigWrite.set("launcher.resultCount", Math.round(v))
        }
    }
}
