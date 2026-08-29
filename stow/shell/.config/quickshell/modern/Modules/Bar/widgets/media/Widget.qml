import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

Item {
    id: root
    visible: Media.hasPlayer
    implicitWidth: visible ? row.implicitWidth + Tokens.spacing.sm : 0
    implicitHeight: Tokens.spacing.xl + Tokens.spacing.xs

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.spacing.xs

        Rectangle {
            visible: Media.trackArtUrl.length > 0
            Layout.preferredWidth: Tokens.spacing.lg
            Layout.preferredHeight: Tokens.spacing.lg
            radius: Tokens.radius.small
            color: Colors.color.surfaceContainerHighest
            clip: true

            Image {
                anchors.fill: parent
                source: Media.trackArtUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Media.raise()
            }
        }

        MText {
            value: Media.trackTitle
            styleName: "labelLarge"
            elide: Text.ElideRight
            Layout.maximumWidth: Tokens.spacing.xxl * 6
        }

        MIconButton {
            iconName: "media-skip-backward-symbolic"
            size: Tokens.spacing.xl
            iconSize: Tokens.icon.sm
            enabled: Media.canGoPrevious
            onClicked: Media.previous()
        }
        MIconButton {
            iconName: Media.playing ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
            size: Tokens.spacing.xl
            iconSize: Tokens.icon.sm
            onClicked: Media.togglePlaying()
        }
        MIconButton {
            iconName: "media-skip-forward-symbolic"
            size: Tokens.spacing.xl
            iconSize: Tokens.icon.sm
            enabled: Media.canGoNext
            onClicked: Media.next()
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: Media.raise()
    }
}
