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
        precision: SystemClock.Minutes
    }

    property bool _entered: false
    readonly property bool _shown: root._entered

    Component.onCompleted: root._entered = true

    Rectangle {
        anchors.fill: parent
        color: Colors.color.surface
    }

    Image {
        anchors.fill: parent
        visible: root.showWallpaper
        source: root.wallpaperFile.length > 0 ? "file://" + root.wallpaperFile : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    Rectangle {
        anchors.fill: parent
        visible: root.showWallpaper
        color: Colors.color.scrim
        opacity: root._shown ? Tokens.overlay.lock : 0

        Behavior on opacity {
            enabled: Motion.overlayFades()
            NumberAnimation {
                duration: Motion.extraLong()
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
            enabled: Motion.overlayFades()
            NumberAnimation {
                duration: Motion.extraLong()
                easing.bezierCurve: root._shown
                    ? Motion.easingEmphasizedDecelerate
                    : Motion.easingEmphasizedAccelerate
            }
        }
        Behavior on scale {
            enabled: Motion.overlayZooms()
            NumberAnimation {
                duration: Motion.extraLong()
                easing.bezierCurve: root._shown
                    ? Motion.easingEmphasizedDecelerate
                    : Motion.easingEmphasizedAccelerate
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width - Tokens.spacing.xxl * 2, Tokens.spacing.xxl * 12)
            spacing: Tokens.spacing.xl

            MAvatar {
                Layout.alignment: Qt.AlignHCenter
                size: Tokens.spacing.xxl * 3
                source: User.faceUrl
            }

            MText {
                Layout.alignment: Qt.AlignHCenter
                value: User.displayName
                styleName: "titleMedium"
            }

            MText {
                Layout.alignment: Qt.AlignHCenter
                value: DateTime.formatTime(clock.date, Config.language.timeFormat || "HH:mm", false)
                styleName: "displayLarge"
            }

            MText {
                Layout.alignment: Qt.AlignHCenter
                value: DateTime.formatDate(clock.date, Config.language.dateFormat || "DD.MM.YYYY")
                styleName: "titleMedium"
                color: Colors.color.onSurfaceVariant
            }

            MTextField {
                id: password
                visible: root.mode !== "shutdown"
                Layout.fillWidth: true
                placeholderKey: "session.password"
                echoMode: TextInput.Password
                onAccepted: Session.authenticate(text)
                Component.onCompleted: forceActiveFocus()
            }

            MText {
                visible: Session.lastError.length > 0
                Layout.alignment: Qt.AlignHCenter
                key: "session.authFailed"
                styleName: "bodySmall"
                color: Colors.color.error
            }

            MButton {
                visible: root.mode !== "shutdown"
                Layout.alignment: Qt.AlignHCenter
                kind: "filled"
                key: "session.unlock"
                onClicked: Session.authenticate(password.text)
            }

            RowLayout {
                visible: root.mode === "shutdown"
                Layout.alignment: Qt.AlignHCenter
                spacing: Tokens.spacing.md

                MButton {
                    kind: "text"
                    key: "powerMenu.cancel"
                    onClicked: Session.unlock()
                }

                MButton {
                    kind: "filled"
                    key: "powerMenu." + (Session.pendingAction === "reboot" ? "restart" : (Session.pendingAction || "poweroff"))
                    onClicked: {
                        if (Session.pendingAction === "reboot")
                            Power.reboot();
                        else if (Session.pendingAction === "logout")
                            Power.logout();
                        else
                            Power.poweroff();
                    }
                }
            }
        }
    }

}
