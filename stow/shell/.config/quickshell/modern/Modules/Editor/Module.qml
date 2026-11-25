import Quickshell
import QtQuick
import "../../Commons"
import "../../Services"
import "../Files" as FilesMod

// ModernOS Texteditor: one window per process (scripts/modern-editor).
// The compositor can close a window outright; with unsaved changes the
// text is kept and an identical window comes straight back to ask about
// it, because a closed Wayland window cannot be shown again.
Scope {
    id: root

    property bool chooser: false
    property bool _quitting: false
    property bool _askOnShow: false

    function quit() {
        if (root._quitting)
            return;
        root._quitting = true;
        EditorPrefs.flush();
        EditorDoc.leave();
        root._leave();
    }

    function _leave() {
        if (!ConfigWrite.pending && !EditorIo.busy)
            Qt.quit();
    }

    function windowClosed(text: string) {
        if (root._quitting)
            return;
        if (!EditorDoc.dirty) {
            root.quit();
            return;
        }
        EditorDoc.restore(text);
        root._askOnShow = true;
        loader.active = false;
        back.start();
    }

    Component.onCompleted: {
        const first = Quickshell.env("MODERN_EDITOR_PATH") || "";
        if (first.length)
            EditorDoc.open(first);
    }

    LazyLoader {
        id: loader
        active: true
        EditorWindow {
            module: root
            askOnShow: root._askOnShow
        }
    }

    // Outside the loader: anything queued from the closed window dies with it.
    Timer {
        id: back
        interval: 0
        onTriggered: loader.active = true
    }

    // The last preference write and claim release must land, but never
    // hold the window hostage.
    Connections {
        target: root._quitting ? ConfigWrite : null
        function onPendingChanged() {
            root._leave();
        }
    }
    Connections {
        target: root._quitting ? EditorIo : null
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
        FilesMod.Module {}
    }
}
