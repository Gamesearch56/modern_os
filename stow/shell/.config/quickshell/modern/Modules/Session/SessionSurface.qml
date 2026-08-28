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
        opacity: Tokens.overlay.lock
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - Tokens.spacing.xxl * 2, Tokens.spacing.xxl * 12)
        spacing: Tokens.spacing.xl

        MText {
            Layout.alignment: Qt.AlignHCenter
            value: root._time()
            styleName: "displayLarge"
        }

        MText {
            Layout.alignment: Qt.AlignHCenter
            value: root._date()
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

    function _pad(n: int): string {
        return n < 10 ? "0" + n : "" + n;
    }

    function _time(): string {
        const d = clock.date;
        if (!d)
            return "";
        return root._pad(d.getHours()) + ":" + root._pad(d.getMinutes());
    }

    function _date(): string {
        const d = clock.date;
        if (!d)
            return "";
        return root._pad(d.getDate()) + "." + root._pad(d.getMonth() + 1) + "." + d.getFullYear();
    }
}
