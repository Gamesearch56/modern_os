// Video Quick Look. A plain window like the picture preview: the clip
// plays muted and on repeat, sized to the video, with the Mediaplayer's
// control bar while the pointer moves over it (VideoBar). Space or Escape
// closes it; Open in the bar hands the file to the player.
import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtMultimedia
import "../../Commons"
import "../../Services"

FloatingWindow {
    id: win

    property bool _spaceLive: false
    // Hyprland keeps a floating window at the size it first mapped with,
    // so the window waits for the frame size before it shows.
    property bool _sized: false
    readonly property MediaPlayer _player: media
    property bool _resting: false
    property bool _keyed: false
    property point _lastPointer: Qt.point(-1, -1)
    readonly property bool _barShown: media.error !== MediaPlayer.NoError || barHover.hovered
        || (!win._resting && (hover.hovered || win._keyed))

    // Qt repeats hover events while the video repaints; only a real move
    // counts as the user being there.
    function _moved(at: point) {
        if (at.x === win._lastPointer.x && at.y === win._lastPointer.y)
            return;
        win._lastPointer = at;
        win._wake();
    }

    function _wake() {
        win._resting = false;
        rest.restart();
    }

    // A seek or mute from the keyboard shows the bar so its effect is visible.
    function _key(act: var) {
        act();
        win._keyed = true;
        win._wake();
    }

    function _screen(): var {
        const n = Hypr.focusedMonitorName();
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].name === n)
                return screens[i];
        }
        return screens.length ? screens[0] : null;
    }

    function _fit() {
        const size = video.sourceRect;
        const screen = win._screen();
        if (!size || !(size.width > 0) || !(size.height > 0) || !screen)
            return;
        const fit = Tokens.window.quicklookFit;
        const scale = Math.min((screen.width * fit) / size.width, (screen.height * fit) / size.height);
        win.implicitWidth = Math.max(1, Math.round(size.width * scale));
        win.implicitHeight = Math.max(1, Math.round(size.height * scale));
        win._sized = true;
    }

    function _url(path: string): string {
        return path.length ? "file://" + path.split("/").map(encodeURIComponent).join("/") : "";
    }

    title: "modern.quicklook"
    color: Colors.color.scrim
    implicitWidth: Tokens.window.overlayWidth
    implicitHeight: Tokens.window.overlayHeight
    screen: win._screen()
    visible: win._sized

    // The opening Space can be delivered when this window first takes
    // focus, which on a slow machine is after a short timer would fire.
    Timer {
        id: spaceLive
        interval: Motion.extraLongMs
        onTriggered: win._spaceLive = true
    }
    Component.onCompleted: spaceLive.restart()
    Timer {
        running: !win._sized
        interval: Motion.extraLongMs
        onTriggered: win._sized = true
    }

    MediaPlayer {
        id: media
        source: win._url(FilePreview.path)
        videoOutput: video
        loops: MediaPlayer.Infinite
        audioOutput: AudioOutput {
            id: sound
            muted: true
        }
        onErrorOccurred: FilePreview.markVideoFailed()
        Component.onCompleted: media.play()
    }

    VideoOutput {
        id: video
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectFit
        onSourceRectChanged: win._fit()
    }

    Item {
        anchors.fill: parent

        HoverHandler {
            id: hover
            cursorShape: win._barShown ? Qt.ArrowCursor : Qt.BlankCursor
            onPointChanged: win._moved(point.position)
            onHoveredChanged: {
                win._lastPointer = Qt.point(-1, -1);
                win._moved(point.position);
            }
        }

        Timer {
            id: rest
            interval: Motion.viewerChromeIdleMs
            onTriggered: {
                win._resting = true;
                win._keyed = false;
            }
        }

        TapHandler {
            acceptedButtons: Qt.LeftButton
            onSingleTapped: bar.togglePlay()
        }

        VideoBar {
            id: bar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Tokens.spacing.md
            media: win._player
            audio: sound
            opacity: win._barShown ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Motion.mediumMs
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.easingStandard
                }
            }

            HoverHandler {
                id: barHover
            }
        }
    }

    Shortcut {
        sequence: "Right"
        context: Qt.WindowShortcut
        onActivated: win._key(() => bar.step(PlayerPrefs.seekSeconds))
    }
    Shortcut {
        sequence: "Left"
        context: Qt.WindowShortcut
        onActivated: win._key(() => bar.step(-PlayerPrefs.seekSeconds))
    }
    Shortcut {
        sequence: "M"
        context: Qt.WindowShortcut
        onActivated: win._key(() => sound.muted = !sound.muted)
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        onActivated: FilePreview.hide()
    }
    Shortcut {
        sequence: "Space"
        enabled: win._spaceLive
        context: Qt.WindowShortcut
        onActivated: FilePreview.spaceHide()
    }
}
