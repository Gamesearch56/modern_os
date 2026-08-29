import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "../../"

Item {
    id: root
    implicitWidth: row.implicitWidth + Tokens.spacing.xs * 2
    implicitHeight: Config.bar.height

    readonly property string _icon: Audio.muted ? "audio-volume-muted-symbolic" : (Audio.volume < 34 ? "audio-volume-low-symbolic" : (Audio.volume < 67 ? "audio-volume-medium-symbolic" : "audio-volume-high-symbolic"))
    readonly property color _fg: sliderPopup.open ? Colors.color.onPrimaryContainer : Colors.color.onSurface

    BarIslandHit {
        checked: sliderPopup.open || (Settings.open && Settings.sectionId === "audio")
        onEntered: {
            hideSlider.stop();
            sliderPopup.open = true;
        }
        onExited: hideSlider.restart()
        onClicked: {
            if (Settings.open && Settings.sectionId === "audio")
                Settings.close();
            else
                Settings.openAt("audio", "");
        }
        onMiddleClicked: Audio.toggleMute()
        onRightClicked: Audio.toggleMute()
        onWheel: (steps) => {
            const step = Config.widgets.audio?.scrollStepPercent ?? 5;
            Audio.adjustVolume(steps > 0 ? step : -step);
        }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        z: 1
        spacing: Tokens.spacing.xs

        MIcon {
            name: root._icon
            size: Tokens.icon.md
            color: root._fg
        }

        MText {
            value: String(Audio.volume) + "%"
            styleName: "labelLarge"
            color: root._fg
        }
    }

    Timer {
        id: hideSlider
        interval: Motion.medium()
        onTriggered: {
            if (!sliderPopup.bodyHovered)
                sliderPopup.open = false;
        }
    }

    BarPopup {
        id: sliderPopup
        open: false
        grab: false
        hoverBridge: true
        barIslandChrome: true
        hAlign: Qt.AlignHCenter
        anchorItem: root
        implicitWidth: Tokens.spacing.xxl * 7
        implicitHeight: Tokens.slider.thumb + Tokens.spacing.md * 3
        onBodyHoveredChanged: {
            if (sliderPopup.bodyHovered)
                hideSlider.stop();
            else
                hideSlider.restart();
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
