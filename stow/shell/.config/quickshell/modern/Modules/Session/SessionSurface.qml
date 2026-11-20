import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../Commons"
import "../../Widgets"
import "../../Services"

Item {
    id: root

    property string mode: Session.mode

    readonly property bool showWallpaper: {
        if (root.mode === "shutdown")
            return false;
        if (root.mode === "lock")
            return Config.design.bootScreen.wallpaperOnLock ?? true;
        return Config.design.bootScreen.wallpaperOnLogin ?? true;
    }

    readonly property string wallpaperFile: {
        if (Wallpaper.currentPath && Wallpaper.currentPath.length > 0)
            return Wallpaper.currentPath;
        return Quickshell.env("HOME") + "/.config/modern/wallpapers/default.jpg";
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    property bool _entered: false
    readonly property bool _shown: root._entered

    Component.onCompleted: root._entered = true

    MouseArea {
        anchors.fill: parent
        onPressed: form.focusPassword()
    }

    Rectangle {
        anchors.fill: parent
        color: Colors.color.surface
        visible: !root.showWallpaper
    }

    MFrost {
        anchors.fill: parent
        visible: root.showWallpaper
        opacity: root._shown ? 1 : 0
        sources: [
            // Another account's shared snapshot must not fill this lock.
            root.wallpaperFile.length > 0 ? "file://" + root.wallpaperFile : "",
            "file://" + Quickshell.env("HOME") + "/.config/modern/wallpapers/default.jpg"
        ]
        washOpacity: Chrome.washOpacity
        scrimOpacity: Tokens.overlay.scrim

        Behavior on opacity {
            enabled: Motion.overlaysFade
            NumberAnimation {
                duration: Motion.extraLongMs
                easing.bezierCurve: Motion.easingEmphasized
            }
        }
    }

    Item {
        id: chrome
        anchors.fill: parent
        scale: Motion.overlayScale(root._shown)
        opacity: Motion.overlayOpacity(root._shown)
        transformOrigin: Item.Center

        Behavior on opacity {
            enabled: Motion.overlaysFade
            NumberAnimation {
                duration: Motion.extraLongMs
                easing.bezierCurve: root._shown
                    ? Motion.easingEmphasizedDecelerate
                    : Motion.easingEmphasizedAccelerate
            }
        }
        Behavior on scale {
            enabled: Motion.overlaysZoom
            NumberAnimation {
                duration: Motion.extraLongMs
                easing.bezierCurve: root._shown
                    ? Motion.easingEmphasizedDecelerate
                    : Motion.easingEmphasizedAccelerate
            }
        }

        SessionClock {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: Tokens.spacing.xxl * 2
            date: clock.date
        }

        ColumnLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(parent.width - Tokens.spacing.xxl * 2, Tokens.spacing.xxl * 12)
            spacing: Tokens.spacing.lg

            MAvatar {
                visible: root.mode !== "shutdown"
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: Tokens.spacing.sm
                size: Tokens.session.avatar
                source: User.faceUrl
                ring: true
                Accessible.ignored: true
            }

            MText {
                visible: root.mode !== "shutdown"
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: Tokens.spacing.xl
                horizontalAlignment: Text.AlignHCenter
                value: User.displayName
                styleName: "headlineMedium"
                Accessible.role: Accessible.StaticText
                Accessible.name: User.displayName
            }

            SessionUnlockForm {
                id: form
                Layout.fillWidth: true
            }
        }
    }
}
