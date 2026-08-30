import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

ColumnLayout {
    id: root
    spacing: Tokens.spacing.lg

    Repeater {
        model: Audio.streams.length
        RowLayout {
            required property int index
            readonly property var stream: Audio.streams[index]
            readonly property string appId: Audio.streamAppId(stream)
            readonly property string iconName: {
                void stream?.ready;
                void stream?.properties;
                const ic = Audio.streamIcon(stream);
                if (ic.length)
                    return ic;
                return Apps.iconForId(appId);
            }
            readonly property string label: {
                const pretty = Apps.labelForId(appId);
                return pretty.length ? pretty : Audio.streamLabel(stream);
            }
            readonly property bool muted: !!(stream && stream.audio && stream.audio.muted)
            readonly property real vol: stream && stream.audio ? Math.round(stream.audio.volume * 100) : 0

            Layout.fillWidth: true
            spacing: Tokens.spacing.md

            MIcon {
                name: iconName
                size: Tokens.icon.md
                tint: false
                preferSymbolic: false
            }
            MText {
                value: label
                styleName: "bodyLarge"
                Layout.fillWidth: true
            }
            MIconButton {
                iconName: muted ? "audio-volume-muted" : "audio-volume-high"
                key: "settings.audio.mute"
                checked: muted
                onClicked: Audio.toggleStreamMute(stream)
            }
            MSlider {
                from: 0
                to: 100
                value: vol
                showValue: true
                Layout.fillWidth: true
                Layout.preferredWidth: Tokens.spacing.xxl * 6
                Layout.minimumWidth: Tokens.spacing.xxl * 4
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
