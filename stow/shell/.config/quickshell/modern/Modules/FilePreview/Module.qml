import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../../Commons"
import "../../Services"

Scope {
    id: root

    IpcHandler {
        target: "filepreview"
        function toggle() { FilePreview.toggle(); }
        function hide() { FilePreview.hide(); }
        function open(path: string) { FilePreview.openPath(path); }
        function isOpen(): string { return FilePreview.open ? "true" : "false"; }
    }

    Connections {
        target: FilePreview
        function onPreviewFailed(key, name) {
            Notifications.toast(I18n.t(key), name);
        }
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
        active: FilePreview.showOverlay

        PanelWindow {
            id: win
            visible: FilePreview.showOverlay
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
                onClosed: FilePreview.hide()
            }

            HyprlandFocusGrab {
                id: keyGrab
                windows: [win]
                onCleared: {
                    if (FilePreview.showOverlay)
                        FilePreview.hide();
                }
            }

            Shortcut {
                sequence: "Escape"
                context: Qt.ApplicationShortcut
                onActivated: FilePreview.hide()
            }
            Shortcut {
                sequence: "Space"
                context: Qt.WindowShortcut
                enabled: FilePreview.showOverlay
                onActivated: FilePreview.hide()
            }

            Component.onCompleted: {
                Qt.callLater(() => {
                    if (!FilePreview.showOverlay)
                        return;
                    keyGrab.active = true;
                });
            }
        }
    }
}
