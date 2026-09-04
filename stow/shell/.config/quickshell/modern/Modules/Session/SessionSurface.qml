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

    MouseArea {
        anchors.fill: parent
        onPressed: {
            if (password.visible && !password.editor.activeFocus)
                password.focusInput();
        }
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
            "file://" + Wallpaper.sessionBlur,
            "file://" + Wallpaper.stateBlur,
            root.wallpaperFile.length > 0 ? "file://" + root.wallpaperFile : ""
        ]
        washOpacity: Config.design.transparency ?? 0.85
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
                focus: true
                holdFocus: true
                placeholderKey: "session.password"
                echoMode: TextInput.Password
                onTextEdited: Session.password = text
                onAccepted: Session.authenticate(Session.password)
                Component.onCompleted: {
                    if (Session.password.length)
                        text = Session.password;
                    focusInput();
                }

                Connections {
                    target: Session
                    function onPasswordChanged() {
                        if (password.text !== Session.password)
                            password.text = Session.password;
                    }
                }
            }

            MText {
                visible: Session.lastError.length > 0
                Layout.alignment: Qt.AlignHCenter
                key: "session.authFailed"
                styleName: "bodySmall"
                color: Colors.color.error
                Accessible.role: Accessible.Alert
                Accessible.name: I18n.t("session.authFailed")
            }

            MButton {
                visible: root.mode !== "shutdown"
                Layout.alignment: Qt.AlignHCenter
                kind: "filled"
                key: "session.unlock"
                tabFocus: false
                enabled: Session.password.length > 0
                onClicked: Session.authenticate(Session.password)
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
