import QtQuick
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

Item {
    id: root
    implicitWidth: Tokens.spacing.xxl
    implicitHeight: Tokens.spacing.xxl

    readonly property string _icon: Audio.muted ? "audio-volume-muted" : (Audio.volume < 34 ? "audio-volume-low" : (Audio.volume < 67 ? "audio-volume-medium" : "audio-volume-high"))

    MIconButton {
        anchors.centerIn: parent
        iconName: root._icon
        key: "bar.volume"
        onClicked: Settings.openAt("audio", "")
        onMiddleClicked: Audio.toggleMute()
        onWheel: (steps) => {
            const step = Config.widgets.audio?.scrollStepPercent ?? 5;
            Audio.adjustVolume(steps > 0 ? step : -step);
        }
    }
}
