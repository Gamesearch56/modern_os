import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

Item {
    id: root
    visible: Media.hasPlayer || !!Audio.playback
    implicitWidth: visible ? (BarLayout.vertical ? Config.bar.height : row.implicitWidth + Tokens.spacing.md * 2) : 0
    implicitHeight: Config.bar.height
    clip: true

    readonly property bool _mpris: Media.hasPlayer
    readonly property real _art: BarLayout.vertical
        ? Config.bar.height - Tokens.spacing.sm
        : Tokens.spacing.xl - Tokens.spacing.xxs
    readonly property real _titleMax: Tokens.spacing.xxl * 4
    readonly property string _label: {
        if (root._mpris) {
            const title = Media.trackTitle || "";
            const artist = Media.trackArtist || "";
            if (title.length > 0 && artist.length > 0)
                return artist + " — " + title;
            return title || artist;
        }
        return Audio.streamTitle(Audio.playback);
    }
    readonly property string _artUrl: root._mpris ? Media.trackArtUrl : ""
    readonly property string _streamIcon: root._mpris ? "" : Audio.streamIcon(Audio.playback)

    function _raise() {
        if (root._mpris) {
            const desk = Media.desktopEntry;
            const ident = Media.identity;
            if ((desk.length > 0 && Hypr.raiseDesktop(desk)) || (ident.length > 0 && Hypr.raiseDesktop(ident)))
                return;
            Media.raise();
            return;
        }
        const app = Audio.streamAppId(Audio.playback);
        if (app.length)
            Hypr.raiseDesktop(app);
    }

    function _toggle() {
        if (root._mpris)
            Media.togglePlaying();
        else
            Audio.toggleStreamMute(Audio.playback);
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.spacing.sm

        Rectangle {
            visible: BarLayout.vertical || root._artUrl.length > 0 || !root._mpris
            Layout.preferredWidth: root._art
            Layout.preferredHeight: root._art
            Layout.alignment: Qt.AlignVCenter
            radius: BarLayout.vertical ? Tokens.radius.full : Tokens.radius.small
            color: Colors.color.surfaceContainerHighest
            clip: true

            Image {
                anchors.fill: parent
                visible: root._artUrl.length > 0
                source: root._artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                sourceSize.width: root._art * 2
                sourceSize.height: root._art * 2
            }

            MIcon {
                anchors.centerIn: parent
                visible: root._artUrl.length === 0
                name: root._streamIcon.length ? root._streamIcon : "audio-x-generic-symbolic"
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
            visible: !BarLayout.vertical && root._mpris
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
            iconName: (root._mpris ? Media.playing : !!Audio.playback) ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
            size: root._art
            iconSize: Tokens.icon.sm
            Layout.alignment: Qt.AlignVCenter
            onClicked: root._toggle()
        }
        MIconButton {
            tabFocus: false
            visible: !BarLayout.vertical && root._mpris
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
