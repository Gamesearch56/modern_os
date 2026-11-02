import QtQuick
import QtQuick.Layouts
import QtQuick.Window
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
        if (Audio.outputHeld)
            out.push({ value: String(Audio.outputSink.id), titleValue: Audio.nodeLabel(Audio.outputSink) });
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
        headerExtra: [
            MButton {
                kind: "text"
                key: "audio.fallback"
                onClicked: outputDlg.open = true
            }
        ]
        ColumnLayout {
            spacing: Tokens.spacing.sm
            MSelect {
                Layout.fillWidth: true
                value: Audio.outputSink ? String(Audio.outputSink.id) : ""
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
        headerExtra: [
            MButton {
                kind: "text"
                key: "audio.fallback"
                onClicked: inputDlg.open = true
            }
        ]
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

    FallbackDialog {
        id: outputDlg
        sink: true
        parent: Window.window ? Window.window.contentItem : root
        anchors.fill: parent
    }

    FallbackDialog {
        id: inputDlg
        sink: false
        parent: Window.window ? Window.window.contentItem : root
        anchors.fill: parent
    }
}
