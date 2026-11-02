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

    MSectionHeader {
        key: "settings.gaming.windows"
        topMargin: 0
    }

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

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.fields.gameHdr"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MSwitch {
            checked: model.hdrSession
            onToggled: (v) => ConfigWrite.set("gaming.hdrSession", v)
        }
    }
    MHint {
        key: "settings.hints.gameHdr"
        Layout.fillWidth: true
    }

    MSectionHeader {
        key: "settings.gaming.slow"
        topMargin: Tokens.spacing.xl
    }


    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.fields.browserLight"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MSwitch {
            checked: model.browserLight
            onToggled: (v) => ConfigWrite.set("gaming.browserLight", v)
        }
    }
    MHint {
        key: "settings.hints.browserLight"
        Layout.fillWidth: true
    }
}
