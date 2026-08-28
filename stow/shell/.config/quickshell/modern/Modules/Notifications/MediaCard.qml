import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

MCard {
    visible: Media.hasPlayer
    Layout.fillWidth: true
    level: 1
    padding: Tokens.spacing.sm

    RowLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.sm

        Image {
            visible: Media.trackArtUrl.length > 0
            Layout.preferredWidth: Tokens.spacing.xxl
            Layout.preferredHeight: Tokens.spacing.xxl
            source: Media.trackArtUrl
            fillMode: Image.PreserveAspectCrop
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            MText {
                value: Media.trackTitle
                styleName: "titleSmall"
                Layout.fillWidth: true
            }
            MText {
                value: Media.trackArtist
                styleName: "bodySmall"
                color: Colors.color.onSurfaceVariant
                Layout.fillWidth: true
            }
        }

        MIconButton {
            iconName: "media-skip-backward"
            onClicked: Media.previous()
        }
        MIconButton {
            iconName: Media.playing ? "media-playback-pause" : "media-playback-start"
            onClicked: Media.togglePlaying()
        }
        MIconButton {
            iconName: "media-skip-forward"
            onClicked: Media.next()
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: Media.raise()
    }
}
