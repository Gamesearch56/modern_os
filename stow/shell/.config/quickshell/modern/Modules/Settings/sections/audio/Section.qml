import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

ColumnLayout {
    spacing: Tokens.spacing.md

    Model { id: model }

    MText {
        key: "settings.sections.audio"
        styleName: "headlineSmall"
        Layout.fillWidth: true
    }

    MText {
        key: "settings.fields.masterVolumeLimit"
        styleName: "titleSmall"
        Layout.fillWidth: true
    }

    MSlider {
        from: 10
        to: 150
        value: model.masterVolumeLimit
        Layout.fillWidth: true
        onMoved: (v) => ConfigWrite.set("audio.masterVolumeLimit", Math.round(v))
    }

    MText {
        value: String(model.masterVolumeLimit)
        styleName: "bodyMedium"
        familyRole: "monospace"
        Layout.fillWidth: true
    }

    MText {
        key: "settings.fields.autoSwitchBluetooth"
        styleName: "titleSmall"
        Layout.fillWidth: true
    }

    MText {
        value: model.autoSwitchBluetooth
        styleName: "bodyMedium"
        familyRole: "monospace"
        Layout.fillWidth: true
    }

    MText {
        key: "settings.cliNote"
        styleName: "bodySmall"
        color: Colors.color.onSurfaceVariant
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
        Layout.fillWidth: true
    }
}
