import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

Item {
    id: root
    visible: Media.hasPlayer
    implicitWidth: visible ? row.implicitWidth + Tokens.spacing.md * 2 : 0
    implicitHeight: Config.bar.height

    readonly property real _art: Tokens.spacing.xl - Tokens.spacing.xxs
    readonly property string _label: {
        const title = Media.trackTitle || "";
        const artist = Media.trackArtist || "";
        if (title.length > 0 && artist.length > 0)
            return title + " — " + artist;
        return title;
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.spacing.sm

        Rectangle {
            visible: Media.trackArtUrl.length > 0
            Layout.preferredWidth: root._art
            Layout.preferredHeight: root._art
            Layout.alignment: Qt.AlignVCenter
            radius: Tokens.radius.small
            color: Colors.color.surfaceContainerHighest
            clip: true

            Image {
                anchors.fill: parent
                source: Media.trackArtUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                sourceSize.width: root._art * 2
                sourceSize.height: root._art * 2
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Media.raise()
            }
        }

        MText {
            value: root._label
            styleName: "titleSmall"
            elide: Text.ElideRight
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: Tokens.spacing.xxl * 10
        }

        MIconButton {
            iconName: "media-skip-backward-symbolic"
            size: root._art
            iconSize: Tokens.icon.sm
            Layout.alignment: Qt.AlignVCenter
            enabled: Media.canGoPrevious
            onClicked: Media.previous()
        }
        MIconButton {
            iconName: Media.playing ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
            size: root._art
            iconSize: Tokens.icon.sm
            Layout.alignment: Qt.AlignVCenter
            onClicked: Media.togglePlaying()
        }
        MIconButton {
            iconName: "media-skip-forward-symbolic"
            size: root._art
            iconSize: Tokens.icon.sm
            Layout.alignment: Qt.AlignVCenter
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
