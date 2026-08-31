import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    id: root
    spacing: Tokens.spacing.lg

    Model { id: model }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.fields.gameFullscreen"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MSwitch {
            checked: model.autoFullscreen
            onToggled: (v) => ConfigWrite.set("gaming.autoFullscreen", v)
        }
    }
    MHint {
        key: "settings.hints.gameFullscreen"
        Layout.fillWidth: true
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.fields.gameOptimize"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MSwitch {
            checked: model.autoOptimize
            onToggled: (v) => ConfigWrite.set("gaming.autoOptimize", v)
        }
    }
    MHint {
        key: "settings.hints.gameOptimize"
        Layout.fillWidth: true
    }
}
