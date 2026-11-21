import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Services"
import "../../Widgets"
import "playops.js" as Ops

// The bar under the video: where it is and how long it runs, the seek
// slider, play and the files around it, volume, speed, tracks, fullscreen.
// Every button goes through `actions`, so a key and a click do the same.
Rectangle {
    id: root

    property var actions: null
    property var playback: null
    readonly property bool menuOpen: speedMenu.open || audioMenu.open || subtitleMenu.open
    readonly property real _duration: root.playback ? root.playback.duration : 0

    implicitHeight: column.implicitHeight + Tokens.spacing.sm * 2
    radius: Tokens.radius.large
    color: Colors.color.surfaceContainer
    border.color: Colors.color.outlineVariant
    border.width: Tokens.stroke.hairline

    function _icon(id: string): string {
        const d = root.actions ? root.actions.def(id) : null;
        return d ? d.icon : "";
    }

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: Tokens.spacing.sm
        anchors.leftMargin: Tokens.spacing.lg
        anchors.rightMargin: Tokens.spacing.lg
        spacing: 0

        MSeekBar {
            id: seekBar
            Layout.fillWidth: true
            position: root.playback ? root.playback.position : 0
            length: root._duration
            seekable: !!root.playback && root.playback.seekable
            nameKey: "player.a11y.seek"
            progressKey: "player.a11y.progress"
            onSeek: (ms) => root.playback.seekTo(ms)
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.xs

            Repeater {
                model: ["previous", "back", "playPause", "forward", "next"]
                delegate: MIconButton {
                    required property string modelData
                    readonly property bool _play: modelData === "playPause"
                    readonly property bool _paused: _play && !!root.playback && !root.playback.playing
                    visible: modelData !== "previous" && modelData !== "next" || PlayerDoc.count > 1
                    iconName: _play ? (_paused ? "media-playback-start" : "media-playback-pause") : root._icon(modelData)
                    key: _play ? (_paused ? "player.actions.play" : "player.actions.pause") : root.actions.def(modelData).key
                    tip: true
                    enabled: !!root.actions && root.actions.enabled(modelData)
                    onClicked: root.actions.run(modelData)
                }
            }

            MIconButton {
                Layout.leftMargin: Tokens.spacing.md
                iconName: PlayerPrefs.muted || PlayerPrefs.volume === 0 ? "audio-volume-muted" : root._icon("volumeUp")
                key: "player.actions.mute"
                tip: true
                checked: PlayerPrefs.muted
                acceptWheel: true
                onClicked: root.actions.run("mute")
                onWheel: (steps) => root.actions.run(steps > 0 ? "volumeUp" : "volumeDown")
            }

            MSlider {
                Layout.preferredWidth: Tokens.spacing.xxl * 3
                from: 0
                to: 1
                value: PlayerPrefs.muted ? 0 : PlayerPrefs.volume
                wheel: true
                wheelStep: PlayerPrefs.volumeStep
                Accessible.name: I18n.t("player.a11y.volume")
                onMoved: (v) => PlayerPrefs.setVolume(v)
            }

            Item {
                Layout.fillWidth: true
            }

            MButton {
                kind: "text"
                key: "player.speed"
                params: ({ speed: Ops.speedLabel(root.playback ? root.playback.rate : 1) })
                highlighted: speedMenu.open
                enabled: !!root.actions && root.actions.enabled("faster")
                Accessible.name: I18n.t("player.menu.speed")
                onClicked: speedMenu.open = !speedMenu.open

                MActionMenu {
                    id: speedMenu
                    actions: root.actions
                    items: root.actions ? root.actions.speedItems() : []
                }
            }

            MIconButton {
                visible: !!root.playback && root.playback.subtitleTracks.length > 0
                iconName: root._icon("subtitles")
                key: "player.menu.subtitles"
                tip: true
                checked: !!root.playback && root.playback.activeSubtitle >= 0
                highlighted: subtitleMenu.open
                onClicked: subtitleMenu.open = !subtitleMenu.open

                MActionMenu {
                    id: subtitleMenu
                    actions: root.actions
                    items: root.actions && subtitleMenu.open ? root.actions.subtitleItems() : []
                }
            }

            MIconButton {
                visible: !!root.playback && root.playback.audioTracks.length > 1
                iconName: root._icon("audioTrack")
                key: "player.menu.audio"
                tip: true
                highlighted: audioMenu.open
                onClicked: audioMenu.open = !audioMenu.open

                MActionMenu {
                    id: audioMenu
                    actions: root.actions
                    items: root.actions && audioMenu.open ? root.actions.audioItems() : []
                }
            }

            MIconButton {
                readonly property bool _full: !!root.actions && root.actions.checked("fullscreen")
                iconName: _full ? "view-restore" : root._icon("fullscreen")
                key: _full ? "player.actions.leave" : "player.actions.fullscreen"
                tip: true
                onClicked: root.actions.run("fullscreen")
            }
        }
    }

    SeekPreview {
        source: Ops.fileUrl(PlayerDoc.path)
        aspect: root.playback ? root.playback.aspect : 0
        at: seekBar.hoverMs
        shown: seekBar.hovering && !!root.playback && root.playback.hasVideo
        x: Math.max(0, Math.min(root.width - width, column.x + seekBar.x + seekBar.hoverX - width / 2))
        y: -height - Tokens.spacing.sm
    }
}
