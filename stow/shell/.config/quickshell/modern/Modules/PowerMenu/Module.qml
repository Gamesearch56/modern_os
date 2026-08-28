import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Scope {
    id: root

    IpcHandler {
        target: "powermenu"
        function toggle() { PowerMenu.toggle(); }
        function show() { PowerMenu.show(); }
        function hide() { PowerMenu.hide(); }
    }

    property string pending: ""

    LazyLoader {
        active: PowerMenu.open

        PanelWindow {
            visible: PowerMenu.open
            color: "transparent"
            anchors.top: true
            anchors.left: true
            anchors.right: true
            anchors.bottom: true
            exclusionMode: ExclusionMode.Ignore
            focusable: true

            MOverlay {
                open: PowerMenu.open
                titleKey: "powerMenu.title"
                cardWidth: Tokens.spacing.xxl * 12
                cardHeight: Tokens.spacing.xxl * 16
                onClosed: {
                    root.pending = "";
                    PowerMenu.hide();
                }

                ColumnLayout {
                    spacing: Tokens.spacing.lg

                    ColumnLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: Tokens.spacing.sm

                        MAvatar {
                            Layout.alignment: Qt.AlignHCenter
                            size: Tokens.spacing.xxl * 3
                            source: User.faceUrl
                        }

                        MText {
                            Layout.alignment: Qt.AlignHCenter
                            value: User.displayName
                            styleName: "titleLarge"
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: Tokens.spacing.sm
                        rowSpacing: Tokens.spacing.sm

                        MButton {
                            kind: "tonal"
                            key: "powerMenu.lock"
                            iconName: "system-lock-screen"
                            fillWidth: true
                            onClicked: {
                                Session.lock();
                                PowerMenu.hide();
                            }
                        }
                        MButton {
                            kind: "tonal"
                            key: "powerMenu.logout"
                            iconName: "system-log-out"
                            fillWidth: true
                            onClicked: root._ask("logout")
                        }
                        MButton {
                            kind: "tonal"
                            key: "powerMenu.suspend"
                            iconName: "system-suspend"
                            fillWidth: true
                            onClicked: {
                                Power.suspend();
                                PowerMenu.hide();
                            }
                        }
                        MButton {
                            kind: "filled"
                            key: "powerMenu.restart"
                            iconName: "system-reboot"
                            fillWidth: true
                            onClicked: root._ask("reboot")
                        }
                        MButton {
                            kind: "destructive"
                            key: "powerMenu.poweroff"
                            iconName: "system-shutdown"
                            fillWidth: true
                            Layout.columnSpan: 2
                            onClicked: root._ask("poweroff")
                        }
                    }
                }
            }

            MDialog {
                anchors.fill: parent
                open: root.pending.length > 0
                titleKey: "powerMenu.confirmTitle"
                bodyKey: "powerMenu.confirmBody"
                bodyParams: ({ action: I18n.t("powerMenu." + (root.pending === "reboot" ? "restart" : root.pending)), seconds: 0 })
                confirmKey: "powerMenu." + (root.pending === "reboot" ? "restart" : (root.pending || "poweroff"))
                destructive: root.pending === "poweroff" || root.pending === "logout"
                onConfirmed: {
                    if (root.pending === "logout")
                        Power.logout();
                    else if (root.pending === "reboot")
                        Power.reboot();
                    else if (root.pending === "poweroff")
                        Power.poweroff();
                    root.pending = "";
                    PowerMenu.hide();
                }
                onCancelled: root.pending = ""
            }

            Shortcut {
                sequence: "Escape"
                onActivated: {
                    root.pending = "";
                    PowerMenu.hide();
                }
            }
        }
    }

    function _ask(action: string) {
        root.pending = action;
    }
}
