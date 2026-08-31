import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "../../"

Item {
    id: root
    implicitWidth: BarLayout.vertical ? Config.bar.height : (row.implicitWidth + Tokens.spacing.sm * 2)
    implicitHeight: Config.bar.height

    readonly property string _icon: Audio.muted ? "audio-volume-muted-symbolic" : (Audio.volume < 34 ? "audio-volume-low-symbolic" : (Audio.volume < 67 ? "audio-volume-medium-symbolic" : "audio-volume-high-symbolic"))
    readonly property color _fg: hit.checked ? Colors.color.onPrimaryContainer : Colors.color.onSurface

    BarIslandHit {
        id: hit
        checked: Settings.open && Settings.sectionId === "audio"
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
        onWheel: (steps, fine) => {
            const step = fine
                ? (Config.widgets.audio?.scrollStepFinePercent ?? 1)
                : (Config.widgets.audio?.scrollStepPercent ?? 5);
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
            visible: !BarLayout.vertical
            value: String(Audio.volume) + "%"
            styleName: "labelLarge"
            color: root._fg
        }
    }

    Timer {
        id: hideSlider
        interval: Motion.mediumMs
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
        implicitHeight: Tokens.slider.thumb + Tokens.spacing.xs + Tokens.spacing.sm * 3
        padding: Tokens.spacing.sm
        onBodyHoveredChanged: {
            if (sliderPopup.bodyHovered)
                hideSlider.stop();
            else
                hideSlider.restart();
        }

        MSlider {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            activeFocusOnTab: false
            from: 0
            to: Audio.volumeCap
            value: Audio.volume
            onMoved: (v) => Audio.setVolume(v)
        }
    }
}
