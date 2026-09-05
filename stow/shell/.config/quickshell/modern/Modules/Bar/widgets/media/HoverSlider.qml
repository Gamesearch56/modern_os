// Hover-only per-app volume (relative). Master gain is the sound slider.
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

    MSlider {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: Tokens.slider.thumb + Tokens.spacing.xs
        activeFocusOnTab: false
        from: 0
        to: 100
        value: Audio.streamVolume(root.stream)
        wheel: true
        onMoved: (v) => Audio.setStreamVolume(root.stream, v)
        onCommitted: (v) => Audio.setStreamVolume(root.stream, v)
    }
}
