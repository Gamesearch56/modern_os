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
        function spaceHide() { FilePreview.spaceHide(); }
        function open(path: string) { FilePreview.openPath(path); }
        function isOpen(): string { return FilePreview.open ? "true" : "false"; }
        function spaceReady(): string { return FilePreview.spaceReady() ? "true" : "false"; }
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
        active: FilePreview.open && (FilePreview.kind === "image" || (FilePreview.kind === "page" && FilePreview.imagePath.length > 0))

        ImageWindow {}
    }

    LazyLoader {
        active: FilePreview.showOverlay

        PanelWindow {
            id: win
            property bool settle: false
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
                    if (!win.settle || !FilePreview.showOverlay)
                        return;
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
                enabled: win.settle && FilePreview.spaceReady()
                context: Qt.ApplicationShortcut
                onActivated: FilePreview.spaceHide()
            }

            Timer {
                id: settleTimer
                interval: Motion.shortMs
                onTriggered: win.settle = true
            }

            Component.onCompleted: {
                Qt.callLater(() => {
                    if (!FilePreview.showOverlay)
                        return;
                    keyGrab.active = true;
                    settleTimer.start();
                });
            }
        }
    }
}
