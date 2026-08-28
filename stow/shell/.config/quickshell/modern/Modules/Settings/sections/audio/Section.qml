import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    spacing: Tokens.spacing.md
    Model { id: model }

    MSectionHeader { key: "audio.output" }
    Repeater {
        model: Audio.sinks
        MListItem {
            required property var modelData
            Layout.fillWidth: true
            iconName: "audio-volume-high"
            titleValue: Audio.nodeLabel(modelData)
            selected: Audio.sink && modelData.id === Audio.sink.id
            onClicked: Audio.setDefaultSink(modelData)
        }
    }
    MText {
        visible: Audio.sinks.length === 0
        key: "audio.noOutputs"
        styleName: "bodyMedium"
        color: Colors.color.onSurfaceVariant
    }
    MSlider {
        Layout.fillWidth: true
        from: 0
        to: Config.audio.masterVolumeLimit ?? 100
        value: Audio.volume
        onMoved: (v) => Audio.setVolume(v)
    }

    MSectionHeader { key: "audio.input" }
    Repeater {
        model: Audio.sources
        MListItem {
            required property var modelData
            Layout.fillWidth: true
            iconName: "audio-input-microphone"
            titleValue: Audio.nodeLabel(modelData)
            selected: Audio.source && modelData.id === Audio.source.id
            onClicked: Audio.setDefaultSource(modelData)
        }
    }
    MText {
        visible: Audio.sources.length === 0
        key: "audio.noInputs"
        styleName: "bodyMedium"
        color: Colors.color.onSurfaceVariant
    }
    MSlider {
        Layout.fillWidth: true
        from: 0
        to: 100
        value: Audio.sourceVolume
        onMoved: (v) => Audio.setSourceVolume(v)
    }

    MHint { key: "settings.hints.audioDevices"; Layout.fillWidth: true }

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
