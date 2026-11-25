import Quickshell
import QtQuick
import "../../Commons"
import "../../Services"
import "../Files" as FilesMod
import "../FilePreview" as FilePreviewMod

// ModernOS Imageviewer: one window per process (scripts/modern-imageviewer),
// like imv. Started with no picture it asks Files for one. The Files
// chooser and its Space preview only load once Open is used.
Scope {
    id: root

    property bool chooser: false
    property bool _quitting: false

    function choose() {
        root.chooser = true;
        FilesChoose.ask(ViewerDoc.folder.length ? ViewerDoc.folder : XdgDirs.pictures, "image", "viewer-open");
    }

    function quit() {
        if (root._quitting)
            return;
        root._quitting = true;
        ViewerPrefs.flush();
        root._leave();
    }

    function _leave() {
        if (!ConfigWrite.pending && !ViewerIo.busy)
            Qt.quit();
    }

    Component.onCompleted: {
        let paths = [];
        try {
            paths = JSON.parse(Quickshell.env("MODERN_VIEWER_ARGS") || "[]");
        } catch (e) {
            paths = [];
        }
        if (Array.isArray(paths) && paths.length)
            ViewerDoc.open(paths);
        else
            Qt.callLater(root.choose);
    }

    LazyLoader {
        active: true
        ViewerWindow {
            module: root
        }
    }

    Connections {
        target: root.chooser ? FilesChoose : null
        function onChosen(path, who) {
            if (who === "viewer-open")
                ViewerDoc.open([path]);
        }
    }

    // A pending rotation save or preference write must land, but never
    // hold the window hostage.
    Connections {
        target: root._quitting ? ConfigWrite : null
        function onPendingChanged() {
            root._leave();
        }
    }
    Connections {
        target: root._quitting ? ViewerIo : null
        function onBusyChanged() {
            root._leave();
        }
    }
    Timer {
        running: root._quitting
        interval: Motion.configWriteMs * 8
        onTriggered: Qt.quit()
    }

    LazyLoader {
        active: root.chooser
        Scope {
            FilesMod.Module {}
            FilePreviewMod.Module {}
        }
    }
}
