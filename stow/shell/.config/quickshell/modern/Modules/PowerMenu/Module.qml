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
            id: win
            visible: PowerMenu.open
            title: "modern.powermenu"
            color: Colors.color.surface
            implicitWidth: Tokens.spacing.xxl * 24 + Tokens.spacing.lg
            implicitHeight: Tokens.spacing.xxl * 16 + Tokens.spacing.lg

            onVisibleChanged: {
                if (visible) {
                    root.focusIndex = 0;
                    win.requestActivate();
                } else {
                    root.pending = "";
                    PowerMenu.hide();
                }
            }

            Rectangle {
                anchors.fill: parent
                color: Colors.color.surface
                radius: Tokens.radius.medium
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.spacing.md
                spacing: Tokens.spacing.md

                MWindowChrome {
                    Layout.fillWidth: true
                    titleKey: "powerMenu.title"
                    subtitleValue: User.displayName
                    titleColumnWidth: Tokens.spacing.xxl * 9
                    onClosed: PowerMenu.hide()
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Tokens.spacing.lg

                    MPane {
                        Layout.preferredWidth: Tokens.spacing.xxl * 9
                        Layout.fillHeight: true

                        Nav {
                            anchors.fill: parent
                            actions: root.actions
                            focusIndex: root.focusIndex
                            onChosen: (i) => {
                                root.focusIndex = i;
                                root._run(root.actions[i].id);
                            }
                        }
                    }

                    Detail {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        action: root.actions[root.focusIndex]
                        onConfirmed: root._run(root.actions[root.focusIndex].id)
                    }
                }
            }

            MDialog {
                anchors.fill: parent
                open: root.pending.length > 0
                titleKey: "powerMenu.confirmTitle"
                bodyKey: "powerMenu.confirmBody"
                bodyParams: ({ action: I18n.t("powerMenu." + (root.pending === "reboot" ? "restart" : root.pending)) })
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
                sequence: "Up"
                onActivated: root.focusIndex = Math.max(0, root.focusIndex - 1)
            }
            Shortcut {
                sequence: "Down"
                onActivated: root.focusIndex = Math.min(root.actions.length - 1, root.focusIndex + 1)
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
