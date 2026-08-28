import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    spacing: Tokens.spacing.md
    Model { id: model }

    MSectionHeader { key: "settings.fields.masterVolumeLimit" }
    MSlider {
        Layout.fillWidth: true
        from: 10
        to: 150
        value: model.masterVolumeLimit
        onMoved: (v) => ConfigWrite.set("audio.masterVolumeLimit", Math.round(v))
    }

    MSectionHeader { key: "settings.fields.autoSwitchBluetooth" }
    RowLayout {
        spacing: Tokens.spacing.sm
        MChip { key: "settings.btAsk"; checked: model.autoSwitchBluetooth === "ask"; onClicked: ConfigWrite.set("audio.autoSwitchBluetooth", "ask") }
        MChip { key: "settings.btOn"; checked: model.autoSwitchBluetooth === "on"; onClicked: ConfigWrite.set("audio.autoSwitchBluetooth", "on") }
        MChip { key: "settings.btOff"; checked: model.autoSwitchBluetooth === "off"; onClicked: ConfigWrite.set("audio.autoSwitchBluetooth", "off") }
    }
}
