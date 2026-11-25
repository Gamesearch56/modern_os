import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../../Services"

Scope {
    id: root

    IpcHandler {
        target: "powermenu"
        function toggle() { PowerMenu.toggle(); }
        // `show` is a `qs ipc` subcommand, so `ipc call powermenu show`
        // prints the target and never runs the handler.
        function open(): void { PowerMenu.show(); }
        function hide() { PowerMenu.hide(); }
    }

    property int focusIndex: -1

    readonly property var actions: [
        { id: "lock", icon: "system-lock-screen-symbolic" },
        { id: "logout", icon: "system-log-out-symbolic" },
        { id: "restart", icon: "system-reboot-symbolic" },
        { id: "poweroff", icon: "system-shutdown-symbolic" }
    ]

    function _run(id: string) {
        if (id === "lock")
            Session.lock();
        else if (id === "logout")
            Power.logout();
        else if (id === "restart")
            Power.reboot();
        else if (id === "poweroff")
            Power.poweroff();
        PowerMenu.hide();
    }

    function _move(delta: int) {
        const n = root.actions.length;
        if (n <= 0)
            return;
        if (root.focusIndex < 0) {
            root.focusIndex = delta > 0 ? 0 : n - 1;
            return;
        }
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
                anchors.fill: parent
                actions: root.actions
                focusIndex: root.focusIndex
                onChosen: (i) => {
                    root.focusIndex = i;
                    root._run(root.actions[i].id);
                }
                onClosed: PowerMenu.hide()
            }

            HyprlandFocusGrab {
                id: keyGrab
                windows: Popups.grabWindows(win, win.screen)
                onCleared: {
                    if (PowerMenu.open)
                        PowerMenu.hide();
                }
            }

            Shortcut {
                sequence: "Escape"
                context: Qt.ApplicationShortcut
                onActivated: PowerMenu.hide()
            }
            Shortcut {
                sequence: "Left"
                onActivated: root._move(-1)
            }
            Shortcut {
                sequence: "Right"
                onActivated: root._move(1)
            }
            Shortcut {
                sequence: "Up"
                onActivated: root._move(-2)
            }
            Shortcut {
                sequence: "Down"
                onActivated: root._move(2)
            }
            Shortcut {
                sequence: "Return"
                onActivated: {
                    if (root.focusIndex < 0)
                        return;
                    root._run(root.actions[root.focusIndex].id);
                }
            }

            Component.onCompleted: {
                root.focusIndex = -1;
                Qt.callLater(() => {
                    if (!PowerMenu.open)
                        return;
                    keyGrab.active = true;
                });
            }
        }
    }
}
