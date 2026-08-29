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

    readonly property string _icon: Audio.muted ? "audio-volume-muted-symbolic" : (Audio.volume < 34 ? "audio-volume-low-symbolic" : (Audio.volume < 67 ? "audio-volume-medium-symbolic" : "audio-volume-high-symbolic"))

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
        id: pill
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onEntered: {
            hideSlider.stop();
            sliderPopup.open = true;
        }
        onExited: hideSlider.restart()
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

    Timer {
        id: hideSlider
        interval: Motion.short()
        onTriggered: {
            if (!popupHover.hovered)
                sliderPopup.open = false;
        }
    }

    BarPopup {
        id: sliderPopup
        open: false
        grab: false
        anchorItem: root
        implicitWidth: Tokens.spacing.xxl * 8
        implicitHeight: Tokens.spacing.xxl * 2

        HoverHandler {
            id: popupHover
            onHoveredChanged: {
                if (hovered) {
                    hideSlider.stop();
                    sliderPopup.open = true;
                } else {
                    hideSlider.restart();
                }
            }
        }

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
