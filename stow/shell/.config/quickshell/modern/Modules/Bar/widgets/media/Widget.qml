import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

Item {
    id: root
    visible: Media.hasPlayer
    implicitWidth: visible ? (BarLayout.vertical ? Config.bar.height : row.implicitWidth + Tokens.spacing.md * 2) : 0
    implicitHeight: Config.bar.height
    clip: true

    readonly property real _art: BarLayout.vertical
        ? Config.bar.height - Tokens.spacing.sm
        : Tokens.spacing.xl - Tokens.spacing.xxs
    readonly property real _titleMax: Tokens.spacing.xxl * 4
    readonly property string _label: {
        const title = Media.trackTitle || "";
        const artist = Media.trackArtist || "";
        if (title.length > 0 && artist.length > 0)
            return artist + " — " + title;
        return title || artist;
    }

    function _raise() {
        const desk = Media.desktopEntry;
        const ident = Media.identity;
        if ((desk.length > 0 && Hypr.raiseDesktop(desk)) || (ident.length > 0 && Hypr.raiseDesktop(ident)))
            return;
        Media.raise();
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.spacing.sm

        Rectangle {
            visible: BarLayout.vertical || Media.trackArtUrl.length > 0
            Layout.preferredWidth: root._art
            Layout.preferredHeight: root._art
            Layout.alignment: Qt.AlignVCenter
            radius: BarLayout.vertical ? Tokens.radius.full : Tokens.radius.small
            color: Colors.color.surfaceContainerHighest
            clip: true

            Image {
                anchors.fill: parent
                visible: Media.trackArtUrl.length > 0
                source: Media.trackArtUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                sourceSize.width: root._art * 2
                sourceSize.height: root._art * 2
            }

            MIcon {
                anchors.centerIn: parent
                visible: Media.trackArtUrl.length === 0
                name: "audio-x-generic-symbolic"
                size: Tokens.icon.md
                color: Colors.color.onSurface
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root._raise()
            }
        }

        Item {
            id: titleBox
            visible: !BarLayout.vertical && root._label.length > 0
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: Math.min(title.implicitWidth, root._titleMax)
            Layout.maximumWidth: root._titleMax
            Layout.preferredHeight: root._art
            implicitHeight: root._art

            MText {
                id: title
                anchors.fill: parent
                value: root._label
                styleName: "titleSmall"
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                verticalAlignment: Text.AlignVCenter
            }
        }

        MIconButton {
            tabFocus: false
            visible: !BarLayout.vertical
            iconName: "media-skip-backward-symbolic"
            size: root._art
            iconSize: Tokens.icon.sm
            Layout.alignment: Qt.AlignVCenter
            enabled: Media.canGoPrevious
            onClicked: Media.previous()
        }
        MIconButton {
            tabFocus: false
            visible: !BarLayout.vertical
            iconName: Media.playing ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
            size: root._art
            iconSize: Tokens.icon.sm
            Layout.alignment: Qt.AlignVCenter
            onClicked: Media.togglePlaying()
        }
        MIconButton {
            tabFocus: false
            visible: !BarLayout.vertical
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
        onClicked: root._raise()
    }
}
