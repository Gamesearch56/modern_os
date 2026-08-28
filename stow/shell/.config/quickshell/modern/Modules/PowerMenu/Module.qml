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
    property int focusIndex: 0

    readonly property var actions: [
        { id: "lock", kind: "tonal", icon: "system-lock-screen" },
        { id: "logout", kind: "tonal", icon: "system-log-out" },
        { id: "suspend", kind: "tonal", icon: "system-suspend" },
        { id: "restart", kind: "filled", icon: "system-reboot" },
        { id: "poweroff", kind: "destructive", icon: "system-shutdown" }
    ]

    function _run(id: string) {
        if (id === "lock") {
            Session.lock();
            PowerMenu.hide();
            return;
        }
        if (id === "suspend") {
            Power.suspend();
            PowerMenu.hide();
            return;
        }
        root._ask(id === "restart" ? "reboot" : id);
    }

    function _ask(action: string) {
        root.pending = action;
    }

    LazyLoader {
        active: PowerMenu.open

        FloatingWindow {
            visible: PowerMenu.open
            title: "modern.powermenu"
            color: Colors.color.surface
            implicitWidth: Tokens.spacing.xxl * 12
            implicitHeight: Tokens.spacing.xxl * 16

            onVisibleChanged: {
                if (!visible) {
                    root.pending = "";
                    PowerMenu.hide();
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.spacing.md
                spacing: Tokens.spacing.md

                MWindowChrome {
                    Layout.fillWidth: true
                    titleKey: "powerMenu.title"
                    onClosed: PowerMenu.hide()
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Tokens.spacing.xxs

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

                    Repeater {
                        model: root.actions
                        MButton {
                            required property var modelData
                            required property int index
                            kind: modelData.kind
                            key: "powerMenu." + modelData.id
                            iconName: modelData.icon
                            fillWidth: true
                            Layout.columnSpan: modelData.id === "poweroff" ? 2 : 1
                            checked: root.focusIndex === index
                            onClicked: root._run(modelData.id)
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
                    if (root.pending.length > 0) {
                        root.pending = "";
                        return;
                    }
                    PowerMenu.hide();
                }
            }
            Shortcut {
                sequence: "Left"
                onActivated: root.focusIndex = Math.max(0, root.focusIndex - 1)
            }
            Shortcut {
                sequence: "Right"
                onActivated: root.focusIndex = Math.min(root.actions.length - 1, root.focusIndex + 1)
            }
            Shortcut {
                sequence: "Up"
                onActivated: root.focusIndex = Math.max(0, root.focusIndex - 2)
            }
            Shortcut {
                sequence: "Down"
                onActivated: root.focusIndex = Math.min(root.actions.length - 1, root.focusIndex + 2)
            }
            Shortcut {
                sequence: "Return"
                onActivated: {
                    if (root.pending.length > 0)
                        return;
                    root._run(root.actions[root.focusIndex].id);
                }
            }
        }
    }
}
