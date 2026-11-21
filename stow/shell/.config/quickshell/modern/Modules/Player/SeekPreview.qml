import QtQuick
import QtMultimedia
import "../../Commons"
import "../../Widgets"
import "playops.js" as Ops

// The frame at a spot on the timeline, shown above it while the pointer
// hovers there. A second, silent MediaPlayer stays paused on the same file
// and seeks to the hovered time, so no thumbnails are made or stored. It
// opens the file on the first hover and seeks at most every
// Motion.seekPreviewMs, however fast the pointer moves.
Rectangle {
    id: root

    property string source: ""
    property real at: 0
    property bool shown: false
    property real aspect: 0
    property bool _armed: false
    property bool _pending: false
    property string _primed: ""
    readonly property real _frameW: Tokens.window.seekPreviewWidth
    readonly property real _frameH: Math.round(root._frameW * root.aspect)

    function _queue() {
        if (gate.running) {
            root._pending = true;
            return;
        }
        root._seek();
        gate.start();
    }

    function _seek() {
        root._pending = false;
        if (media.seekable)
            media.position = Ops.seekTarget(root.at, 0, media.duration);
    }

    implicitWidth: root._frameW + Tokens.spacing.xs * 2
    implicitHeight: content.implicitHeight + Tokens.spacing.xs * 2
    radius: Tokens.radius.medium
    color: Colors.color.surfaceContainer
    border.color: Colors.color.outlineVariant
    border.width: Tokens.stroke.hairline
    opacity: root.shown ? 1 : 0
    visible: opacity > 0

    onShownChanged: if (root.shown && root.source.length) root._armed = true
    onSourceChanged: root._armed = root.shown
    onAtChanged: if (root._armed) root._queue()

    Behavior on opacity {
        NumberAnimation {
            duration: Motion.shortMs
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.easingStandard
        }
    }

    Timer {
        id: gate
        interval: Motion.seekPreviewMs
        onTriggered: {
            if (!root._pending)
                return;
            root._seek();
            gate.start();
        }
    }

    MediaPlayer {
        id: media
        source: root._armed ? root.source : ""
        videoOutput: frame
        // Pausing re-reports the loaded state, so the file is primed once.
        onMediaStatusChanged: {
            if (media.mediaStatus !== MediaPlayer.LoadedMedia || root._primed === String(media.source))
                return;
            root._primed = String(media.source);
            media.pause();
            Qt.callLater(root._seek);
        }
    }

    Column {
        id: content
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Tokens.spacing.xs
        spacing: Tokens.spacing.xs

        Rectangle {
            width: root._frameW
            height: root._frameH
            radius: Tokens.radius.small
            color: Colors.color.scrim
            clip: true

            VideoOutput {
                id: frame
                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectFit
            }
        }

        MText {
            anchors.horizontalCenter: parent.horizontalCenter
            value: Ops.clock(root.at)
            styleName: "labelLarge"
            font.features: { "tnum": 1 }
        }
    }
}
