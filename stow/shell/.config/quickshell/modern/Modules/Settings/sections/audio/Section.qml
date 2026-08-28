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
}
