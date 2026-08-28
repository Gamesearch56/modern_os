import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

Item {
    id: root
    implicitWidth: row.implicitWidth + Tokens.spacing.md
    implicitHeight: Tokens.spacing.xl + Tokens.spacing.xs

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.spacing.xs

        MIcon {
            name: Media.playing ? "media-playback-pause" : "media-playback-start"
            size: Tokens.spacing.lg
        }

        MText {
            value: Media.hasPlayer ? (Media.trackArtist + " - " + Media.trackTitle) : I18n.t("media.notPlaying")
            styleName: "labelLarge"
            elide: Text.ElideRight
            Layout.maximumWidth: Tokens.spacing.xxl * 8
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.MiddleButton) {
                if (Media.hasPlayer)
                    Media.togglePlaying();
                else
                    Media.launchSpotify();
                return;
            }
            if (!Media.hasPlayer) {
                Media.launchSpotify();
                return;
            }
            panel.open = !panel.open;
        }
        onWheel: (w) => {
            if (Media.canSeek)
                Media.seek(w.angleDelta.y > 0 ? 5 : -5);
        }
    }

    MPopup {
        id: panel
        open: false
        width: Tokens.spacing.xxl * 10
        height: Tokens.spacing.xxl * 8
        anchors.top: parent.bottom
        anchors.topMargin: Tokens.spacing.sm

        ColumnLayout {
            anchors.fill: parent
            spacing: Tokens.spacing.sm

            MText {
                value: Media.trackTitle
                styleName: "titleMedium"
                Layout.fillWidth: true
            }
            MText {
                value: Media.trackArtist
                styleName: "bodySmall"
                color: Colors.color.onSurfaceVariant
                Layout.fillWidth: true
            }

            MSlider {
                Layout.fillWidth: true
                from: 0
                to: Math.max(1, Media.length)
                value: Media.position
                onMoved: (v) => Media.setPosition(v)
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Tokens.spacing.sm

                MIconButton { iconName: "media-skip-backward"; onClicked: Media.previous() }
                MIconButton { iconName: Media.playing ? "media-playback-pause" : "media-playback-start"; onClicked: Media.togglePlaying() }
                MIconButton { iconName: "media-playback-stop"; onClicked: Media.stop() }
                MIconButton { iconName: "media-skip-forward"; onClicked: Media.next() }
            }
        }
    }
}
