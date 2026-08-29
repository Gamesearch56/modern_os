import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    spacing: Tokens.spacing.md
    Model { id: model }

    function _sinkModel(): var {
        const out = [];
        const list = Audio.sinks;
        for (let i = 0; i < list.length; i++)
            out.push({ value: String(list[i].id), titleValue: Audio.nodeLabel(list[i]) });
        return out;
    }

    function _sourceModel(): var {
        const out = [];
        const list = Audio.sources;
        for (let i = 0; i < list.length; i++)
            out.push({ value: String(list[i].id), titleValue: Audio.nodeLabel(list[i]) });
        return out;
    }

    function _find(id) {
        const list = Audio.trackedNodes;
        for (let i = 0; i < list.length; i++) {
            if (String(list[i].id) === String(id))
                return list[i];
        }
        return null;
    }

    MSectionHeader { key: "settings.fields.masterVolumeLimit" }
    MSlider {
        Layout.fillWidth: true
        from: 10
        to: 150
        value: model.masterVolumeLimit
        showValue: true
        onMoved: (v) => ConfigWrite.set("audio.masterVolumeLimit", Math.round(v))
    }

    MSectionHeader { key: "audio.output" }
    MSelect {
        Layout.fillWidth: true
        value: Audio.sink ? String(Audio.sink.id) : ""
        model: _sinkModel()
        placeholderKey: "audio.noOutputs"
        onSelected: (v) => Audio.setDefaultSink(_find(v))
    }
    MSlider {
        Layout.fillWidth: true
        from: 0
        to: Config.audio.masterVolumeLimit ?? 100
        value: Audio.volume
        showValue: true
        onMoved: (v) => Audio.setVolume(v)
    }

    MSectionHeader { key: "audio.input" }
    MSelect {
        Layout.fillWidth: true
        value: Audio.source ? String(Audio.source.id) : ""
        model: _sourceModel()
        placeholderKey: "audio.noInputs"
        onSelected: (v) => Audio.setDefaultSource(_find(v))
    }
    MSlider {
        Layout.fillWidth: true
        from: 0
        to: 100
        value: Audio.sourceVolume
        onMoved: (v) => Audio.setSourceVolume(v)
    }

    MSectionHeader { key: "settings.fields.autoSwitchBluetooth" }
    MSegmented {
        Layout.fillWidth: true
        value: Config.audio.autoSwitchBluetooth || "ask"
        model: [
            { value: "ask", titleKey: "settings.btAsk" },
            { value: "on", titleKey: "settings.btOn" },
            { value: "off", titleKey: "settings.btOff" }
        ]
        onSelected: (v) => ConfigWrite.set("audio.autoSwitchBluetooth", v)
    }

    MSectionHeader { key: "settings.fields.perAppVolume" }
    Repeater {
        model: Audio.streams.length
        MListItem {
            required property int index
            readonly property var stream: Audio.streams[index]
            Layout.fillWidth: true
            titleValue: Audio.nodeLabel(stream)
            MSlider {
                from: 0
                to: 100
                value: stream && stream.audio ? Math.round(stream.audio.volume * 100) : 0
                onMoved: (v) => Audio.setStreamVolume(stream, v)
            }
        }
    }
    MEmptyState {
        visible: Audio.streams.length === 0
        Layout.fillWidth: true
        Layout.preferredHeight: Tokens.spacing.xxl * 3
        iconName: "audio-volume-muted"
        titleKey: "settings.audio.emptyStreams"
    }
}
