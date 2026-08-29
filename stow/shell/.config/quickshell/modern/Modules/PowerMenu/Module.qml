import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
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
        { id: "lock", icon: "system-lock-screen-symbolic" },
        { id: "logout", icon: "system-log-out-symbolic" },
        { id: "restart", icon: "system-reboot-symbolic" },
        { id: "poweroff", icon: "system-shutdown-symbolic" }
    ]

    function _run(id: string) {
        if (id === "lock") {
            Session.lock();
            PowerMenu.hide();
            return;
        }
        root._ask(id === "restart" ? "reboot" : id);
    }

    function _ask(action: string) {
        root.pending = action;
    }

    function _move(delta: int) {
        const n = root.actions.length;
        root.focusIndex = Math.max(0, Math.min(n - 1, root.focusIndex + delta));
    }

    function _focusedScreen(): var {
        const n = Hypr.focusedMonitorName();
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].name === n)
                return screens[i];
        }
        return screens.length ? screens[0] : null;
    }

    LazyLoader {
        active: PowerMenu.open

        PanelWindow {
            id: win
            visible: PowerMenu.open
            screen: root._focusedScreen()
            color: "transparent"
            anchors.top: true
            anchors.left: true
            anchors.right: true
            anchors.bottom: true
            exclusionMode: ExclusionMode.Ignore
            focusable: true
            aboveWindows: true
            WlrLayershell.layer: WlrLayer.Overlay

            Overlay {
                id: overlay
                anchors.fill: parent
                actions: root.actions
                focusIndex: root.focusIndex
                onChosen: (i) => {
                    root.focusIndex = i;
                    root._run(root.actions[i].id);
                }
                onClosed: {
                    if (root.pending.length > 0)
                        root.pending = "";
                    else
                        PowerMenu.hide();
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

            HyprlandFocusGrab {
                id: keyGrab
                windows: [win]
                onCleared: {
                    if (PowerMenu.open)
                        PowerMenu.hide();
                }
            }

            Shortcut {
                sequence: "Escape"
                context: Qt.ApplicationShortcut
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
                enabled: root.pending.length === 0
                onActivated: root._move(-1)
            }
            Shortcut {
                sequence: "Right"
                enabled: root.pending.length === 0
                onActivated: root._move(1)
            }
            Shortcut {
                sequence: "Up"
                enabled: root.pending.length === 0
                onActivated: root._move(-2)
            }
            Shortcut {
                sequence: "Down"
                enabled: root.pending.length === 0
                onActivated: root._move(2)
            }
            Shortcut {
                sequence: "Return"
                enabled: root.pending.length === 0
                onActivated: root._run(root.actions[root.focusIndex].id)
            }

            Component.onCompleted: {
                root.focusIndex = 0;
                root.pending = "";
                Qt.callLater(() => {
                    if (!PowerMenu.open)
                        return;
                    keyGrab.active = true;
                });
            }
        }
    }
}
