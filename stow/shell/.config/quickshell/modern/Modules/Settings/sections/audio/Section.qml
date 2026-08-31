import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    id: root
    spacing: Tokens.spacing.lg

    Model { id: sectionModel }

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

    MField {
        labelKey: "settings.fields.masterVolumeLimit"
        MSlider {
            from: 10
            to: 150
            value: sectionModel.masterVolumeLimit
            showValue: true
            onCommitted: (v) => {
                const n = Math.round(v);
                ConfigWrite.set("audio.masterVolumeLimit", n);
                if (Audio.volume > n)
                    Audio.setVolume(n);
            }
        }
    }

    MField {
        labelKey: "audio.output"
        ColumnLayout {
            spacing: Tokens.spacing.sm
            MSelect {
                Layout.fillWidth: true
                value: Audio.sink ? String(Audio.sink.id) : ""
                model: root._sinkModel()
                placeholderKey: "audio.noOutputs"
                onSelected: (v) => Audio.setDefaultSink(root._find(v))
            }
            MSlider {
                Layout.fillWidth: true
                from: 0
                to: Audio.volumeCap
                value: Audio.volume
                showValue: true
                onMoved: (v) => Audio.setVolume(v)
            }
        }
    }

    MField {
        labelKey: "audio.input"
        ColumnLayout {
            spacing: Tokens.spacing.sm
            MSelect {
                Layout.fillWidth: true
                value: Audio.source ? String(Audio.source.id) : ""
                model: root._sourceModel()
                placeholderKey: "audio.noInputs"
                onSelected: (v) => Audio.setDefaultSource(root._find(v))
            }
            MSlider {
                Layout.fillWidth: true
                from: 0
                to: 100
                value: Audio.sourceVolume
                showValue: true
                onMoved: (v) => Audio.setSourceVolume(v)
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.xs
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.md
            MText {
                key: "settings.fields.autoSwitchBluetooth"
                styleName: "bodyMedium"
                color: Colors.color.onSurfaceVariant
                Layout.fillWidth: true
            }
            MSwitch {
                checked: sectionModel.autoBluetooth
                onToggled: (v) => ConfigWrite.set("audio.autoSwitchBluetooth", v ? "on" : "off")
            }
        }
        MHint {
            key: "settings.hints.autoSwitchBluetooth"
            Layout.fillWidth: true
        }
    }

    MSectionHeader {
        key: "settings.fields.perAppVolume"
        topMargin: Tokens.spacing.xl
    }
    StreamList {
        Layout.fillWidth: true
    }
}
