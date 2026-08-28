import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "../../"

Item {
    id: root
    implicitWidth: row.implicitWidth + Tokens.spacing.sm
    implicitHeight: Tokens.spacing.xl + Tokens.spacing.xs

    readonly property string _icon: Audio.muted ? "audio-volume-muted" : (Audio.volume < 34 ? "audio-volume-low" : (Audio.volume < 67 ? "audio-volume-medium" : "audio-volume-high"))

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.spacing.xs

        MIcon {
            name: root._icon
            size: Tokens.icon.md
        }

        MText {
            value: String(Audio.volume) + "%"
            styleName: "labelLarge"
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onEntered: sliderPopup.open = true
        onExited: sliderPopup.open = false
        onClicked: (m) => {
            if (m.button === Qt.MiddleButton)
                Audio.toggleMute();
            else
                Settings.openAt("audio", "");
        }
        onWheel: (w) => {
            const step = Config.widgets.audio?.scrollStepPercent ?? 5;
            Audio.adjustVolume(w.angleDelta.y > 0 ? step : -step);
        }
    }

    BarPopup {
        id: sliderPopup
        open: false
        width: Tokens.spacing.xxl * 8
        height: Tokens.spacing.xxl * 2
        y: root.height + Tokens.spacing.sm
        x: 0

        MSlider {
            anchors.centerIn: parent
            width: parent.width - Tokens.spacing.md
            from: 0
            to: Config.audio.masterVolumeLimit ?? 100
            value: Audio.volume
            onMoved: (v) => Audio.setVolume(v)
        }
    }
}
