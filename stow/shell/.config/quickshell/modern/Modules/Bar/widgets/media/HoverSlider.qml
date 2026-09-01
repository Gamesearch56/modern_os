// Hover-only stream volume, same chrome as the bar sound slider.
import QtQuick
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "../../"

BarPopup {
    id: root

    property var stream: null
    property bool appActive: false

    open: false
    grab: false
    hoverBridge: true
    barIslandChrome: true
    hAlign: Qt.AlignHCenter
    implicitWidth: Tokens.spacing.xxl * 7
    implicitHeight: Tokens.slider.thumb + Tokens.spacing.xs + Tokens.spacing.sm * 3
    padding: Tokens.spacing.sm

    function nudge(steps: real, fine: bool) {
        const n = root.stream;
        if (!n || !n.audio)
            return;
        const step = fine
            ? (Config.widgets.audio?.scrollStepFinePercent ?? 1)
            : (Config.widgets.audio?.scrollStepPercent ?? 5);
        Audio.adjustStreamVolume(n, steps > 0 ? step : -step);
    }

    function setPillHovered(hovered: bool) {
        if (!root.appActive || !root.stream || !root.stream.audio) {
            root.open = false;
            return;
        }
        if (hovered) {
            hideTimer.stop();
            root.open = true;
        } else {
            hideTimer.restart();
        }
    }

    onStreamChanged: {
        if (!root.stream)
            root.open = false;
    }
    onAppActiveChanged: {
        if (!root.appActive)
            root.open = false;
    }
    onBodyHoveredChanged: {
        if (root.bodyHovered)
            hideTimer.stop();
        else
            hideTimer.restart();
    }

    Timer {
        id: hideTimer
        interval: Motion.mediumMs
        onTriggered: {
            if (!root.bodyHovered)
                root.open = false;
        }
    }

    MouseArea {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: Tokens.slider.thumb + Tokens.spacing.xs
        acceptedButtons: Qt.NoButton
        onWheel: (w) => {
            root.nudge(w.angleDelta.y > 0 ? 1 : -1, !!(w.modifiers & Qt.ShiftModifier));
            w.accepted = true;
        }

        MSlider {
            anchors.fill: parent
            activeFocusOnTab: false
            from: 0
            to: 100
            value: {
                const n = root.stream;
                if (!n || !n.audio)
                    return 0;
                void n.audio.volume;
                return Math.round(n.audio.volume * 100);
            }
            onMoved: (v) => Audio.setStreamVolume(root.stream, v)
        }
    }
}
