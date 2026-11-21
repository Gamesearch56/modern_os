import QtQuick
import QtMultimedia
import "../../Commons"
import "../../Widgets"
import "../../Services"
import "playops.js" as Ops

// The picture and the sound: Qt Multimedia plays PlayerDoc.path with the
// FFmpeg backend (hardware decoding where the GPU offers it). A song shows
// its name instead of a picture; a file that cannot play says so. One click
// pauses, a double click asks for fullscreen, the wheel sets the volume and
// Ctrl+wheel zooms the picture around the pointer (VideoView).
FocusScope {
    id: root

    readonly property bool playing: media.playbackState === MediaPlayer.PlayingState
    readonly property bool failed: media.error !== MediaPlayer.NoError
    readonly property bool ready: !root.failed && media.mediaStatus !== MediaPlayer.NoMedia
        && media.mediaStatus !== MediaPlayer.LoadingMedia && media.mediaStatus !== MediaPlayer.InvalidMedia
    readonly property bool hasVideo: media.hasVideo
    readonly property real position: media.position
    readonly property real duration: media.duration
    readonly property bool seekable: media.seekable
    readonly property real rate: media.playbackRate
    readonly property int activeAudio: media.activeAudioTrack
    readonly property int activeSubtitle: media.activeSubtitleTrack
    readonly property var audioTracks: root._labels(media.audioTracks)
    readonly property var subtitleTracks: root._labels(media.subtitleTracks)

    signal tapped()
    signal doubleTapped()
    signal wheeled(real steps)
    signal zoomed(real zoom)

    function _labels(tracks: var): var {
        return (tracks || []).map(t => ({
            label: Ops.trackLabel(t.stringValue(MediaMetaData.Title), t.stringValue(MediaMetaData.Language))
        }));
    }

    function togglePlay() {
        if (root.playing)
            media.pause();
        else
            media.play();
    }

    function seekTo(ms: real) {
        if (root.seekable)
            media.position = Ops.seekTarget(ms, 0, root.duration);
    }

    function seekBy(ms: real) {
        root.seekTo(root.position + ms);
    }

    // Qt has no frame step; a paused seek by one frame is what mpv shows too.
    function step(frames: int) {
        media.pause();
        root.seekBy(frames * Ops.frameMs(media.metaData.value(MediaMetaData.VideoFrameRate)));
    }

    function setRate(r: real) {
        media.playbackRate = r;
    }

    function setAudio(i: int) {
        media.activeAudioTrack = i;
    }

    function setSubtitle(i: int) {
        media.activeSubtitleTrack = i;
    }

    function trackName(tracks: var, i: int): string {
        const t = tracks[i];
        return t && t.label.length ? t.label : I18n.t("player.menu.track", { number: i + 1 });
    }

    function _load() {
        const rate = media.playbackRate;
        view.reset();
        media.source = Ops.fileUrl(PlayerDoc.path);
        media.playbackRate = rate;
        media.play();
    }

    Accessible.role: Accessible.Animation
    Accessible.name: I18n.t("player.a11y.video", { name: PlayerDoc.name, index: PlayerDoc.index + 1, count: PlayerDoc.count })
    Accessible.description: I18n.t("player.a11y.progress", { position: Ops.clock(root.position), duration: Ops.clock(root.duration) })

    MediaPlayer {
        id: media
        videoOutput: view.output
        audioOutput: AudioOutput {
            volume: Ops.gain(PlayerPrefs.volume)
            muted: PlayerPrefs.muted
        }
        loops: PlayerPrefs.loop ? MediaPlayer.Infinite : 1
        onMediaStatusChanged: {
            if (media.mediaStatus === MediaPlayer.EndOfMedia && !PlayerPrefs.loop
                    && PlayerDoc.index < PlayerDoc.count - 1)
                PlayerDoc.next();
        }
    }

    Connections {
        target: PlayerDoc
        function onShown() {
            root._load();
        }
    }

    VideoView {
        id: view
        anchors.fill: parent
        visible: root.hasVideo && !root.failed
    }

    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - Tokens.spacing.xxl * 2, Tokens.spacing.xxl * 12)
        spacing: Tokens.spacing.lg
        visible: root.ready && !root.hasVideo

        MIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: "audio-x-generic"
            size: Tokens.icon.lg * 2
            color: Colors.color.primary
        }

        MText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            value: PlayerDoc.name
            styleName: "titleLarge"
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
        }
    }

    MEmptyState {
        anchors.fill: parent
        visible: root.failed
        iconName: "dialog-warning"
        titleKey: "player.errors.cannotPlay"
        hintKey: "player.errors.cannotPlayHint"
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onSingleTapped: root.tapped()
        onDoubleTapped: root.doubleTapped()
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (w) => {
            const steps = Ops.notches(w.angleDelta.y, w.pixelDelta.y);
            if (!(w.modifiers & Qt.ControlModifier)) {
                root.wheeled(steps);
            } else if (root.hasVideo && steps) {
                view.zoomBy(steps, w.x, w.y);
                root.zoomed(view.zoom);
            }
        }
    }
}
