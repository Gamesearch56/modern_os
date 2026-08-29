import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../../Commons"
import "../../Services"

Scope {
    id: root

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
        active: Wallpaper.pickerOpen

        PanelWindow {
            id: win
            visible: Wallpaper.pickerOpen
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
                onClosed: Wallpaper.hide()
            }

            HyprlandFocusGrab {
                id: keyGrab
                windows: [win]
                onCleared: {
                    if (Wallpaper.pickerOpen)
                        Wallpaper.hide();
                }
            }

            Shortcut {
                sequence: "Escape"
                context: Qt.ApplicationShortcut
                onActivated: Wallpaper.hide()
            }
            Shortcut {
                enabled: Wallpaper.images.length > 0
                sequence: "Left"
                onActivated: overlay.moveBy(-1)
            }
            Shortcut {
                enabled: Wallpaper.images.length > 0
                sequence: "Right"
                onActivated: overlay.moveBy(1)
            }
            Shortcut {
                enabled: Wallpaper.images.length > 0
                sequence: "Up"
                onActivated: overlay.moveBy(-overlay.columns)
            }
            Shortcut {
                enabled: Wallpaper.images.length > 0
                sequence: "Down"
                onActivated: overlay.moveBy(overlay.columns)
            }
            Shortcut {
                enabled: Wallpaper.images.length > 0
                sequence: "Return"
                onActivated: overlay.activate()
            }
            Shortcut {
                enabled: Wallpaper.images.length > 0
                sequence: "Enter"
                onActivated: overlay.activate()
            }

            Component.onCompleted: {
                Qt.callLater(() => {
                    if (!Wallpaper.pickerOpen)
                        return;
                    keyGrab.active = true;
                });
            }
        }
    }
}
