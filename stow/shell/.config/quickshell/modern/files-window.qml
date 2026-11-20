// A file manager window besides the main one. Launched with qs -p so it
// stays in this config, without starting another bar or panel.
import Quickshell
import QtQuick
import "Commons"
import "Services"
import "Modules/Files" as FilesMod
import "Modules/FilePreview" as FilePreviewMod

ShellRoot {
    id: root

    property bool _up: false

    FilesMod.Module {}
    FilePreviewMod.Module {}

    Component.onCompleted: Files.show(Quickshell.env("MODERN_FILE_PATH") || "", true)

    Timer {
        interval: Motion.longMs
        running: true
        onTriggered: {
            root._up = true;
            if (!Files.open) {
                Qt.quit();
                return;
            }
            Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "pid:" + Quickshell.processId]);
        }
    }

    Connections {
        target: Files
        function onOpenChanged() {
            if (root._up && !Files.open)
                Qt.quit();
        }
    }
}
