import Quickshell
import QtQuick
import "../../Commons"
import "../../Services"
import "../Files" as FilesMod
import "../FilePreview" as FilePreviewMod

// ModernOS Mediaplayer: one window per process (scripts/modern-mediaplayer).
// Started with no file it asks Files for one. The Files chooser and its
// Space preview only load once Open is used.
Scope {
    id: root

    property bool chooser: false
    property bool _quitting: false

    function choose() {
        root.chooser = true;
        FilesChoose.ask(PlayerDoc.folder.length ? PlayerDoc.folder : XdgDirs.videos, "media", "player-open");
    }

    function quit() {
        if (root._quitting)
            return;
        root._quitting = true;
        PlayerPrefs.flush();
        root._leave();
    }

    function _leave() {
        if (!ConfigWrite.pending && !PlayerIo.busy)
            Qt.quit();
    }

    Component.onCompleted: {
        let paths = [];
        try {
            paths = JSON.parse(Quickshell.env("MODERN_PLAYER_ARGS") || "[]");
        } catch (e) {
            paths = [];
        }
        if (Array.isArray(paths) && paths.length)
            PlayerDoc.open(paths);
        else
            Qt.callLater(root.choose);
    }

    LazyLoader {
        active: true
        PlayerWindow {
            module: root
        }
    }

    Connections {
        target: root.chooser ? FilesChoose : null
        function onChosen(path, who) {
            if (who === "player-open")
                PlayerDoc.open([path]);
        }
    }

    // A frame being saved or a preference write must land, but never hold
    // the window hostage.
    Connections {
        target: root._quitting ? ConfigWrite : null
        function onPendingChanged() {
            root._leave();
        }
    }
    Connections {
        target: root._quitting ? PlayerIo : null
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
