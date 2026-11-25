import QtQuick
import QtQuick.Layouts
import QtMultimedia
import "../../Commons"
import "../../Services"
import "../../Widgets"

// The control bar under a video preview, the Mediaplayer's in small: seek,
// play, a step back and forward, sound, and Open for the whole player.
// The preview stays muted until you unmute it here; nothing is saved.
Rectangle {
    id: root

    property MediaPlayer media: null
    property AudioOutput audio: null
    readonly property bool _playing: !!root.media && root.media.playbackState === MediaPlayer.PlayingState

    function step(seconds: int) {
        if (!root.media || !root.media.seekable)
            return;
        const end = Math.max(0, root.media.duration - 1);
        root.media.position = Math.max(0, Math.min(end, root.media.position + seconds * 1000));
    }

    function togglePlay() {
        if (root._playing)
            root.media.pause();
        else
            root.media.play();
    }

    implicitHeight: column.implicitHeight + Tokens.spacing.sm * 2
    radius: Tokens.radius.large
    color: Colors.color.surfaceContainer
    border.color: Colors.color.outlineVariant
    border.width: Tokens.stroke.hairline

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: Tokens.spacing.sm
        anchors.leftMargin: Tokens.spacing.lg
        anchors.rightMargin: Tokens.spacing.lg
        spacing: 0

        MSeekBar {
            Layout.fillWidth: true
            position: root.media ? root.media.position : 0
            length: root.media ? root.media.duration : 0
            seekable: !!root.media && root.media.seekable
            nameKey: "player.a11y.seek"
            progressKey: "player.a11y.progress"
            onSeek: (ms) => root.media.position = ms
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.xs

            MIconButton {
                iconName: "media-seek-backward"
                key: "player.actions.back"
                tip: true
                onClicked: root.step(-PlayerPrefs.seekSeconds)
            }

            MIconButton {
                iconName: root._playing ? "media-playback-pause" : "media-playback-start"
                key: root._playing ? "player.actions.pause" : "player.actions.play"
                tip: true
                onClicked: root.togglePlay()
            }

            MIconButton {
                iconName: "media-seek-forward"
                key: "player.actions.forward"
                tip: true
                onClicked: root.step(PlayerPrefs.seekSeconds)
            }

            MIconButton {
                Layout.leftMargin: Tokens.spacing.md
                iconName: !root.audio || root.audio.muted ? "audio-volume-muted" : "audio-volume-high"
                key: "player.actions.mute"
                tip: true
                checked: !!root.audio && root.audio.muted
                onClicked: root.audio.muted = !root.audio.muted
            }

            Item {
                Layout.fillWidth: true
            }

            MButton {
                kind: "text"
                key: "filePreview.openFull"
                iconName: "modern-mediaplayer-symbolic"
                onClicked: FilePreview.openFull()
            }
        }
    }
}
