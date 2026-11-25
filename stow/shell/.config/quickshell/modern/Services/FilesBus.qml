// Claims the file-manager bus name so folder requests reach this shell.
pragma Singleton

import Quickshell
import QtQuick
import "../Commons"

Singleton {
    id: root
    property bool _started: false

    function _start() {
        if (root._started)
            return;
        // Paths.repo is a home-relative guess until the repo file loads.
        // Starting on that guess runs a missing script and never retries.
        if (!Paths._envRepo.length && !Paths._fileRepo.length)
            return;
        root._started = true;
        Quickshell.execDetached([Paths.script("file-manager-bus.py")]);
    }

    Component.onCompleted: Qt.callLater(root._start)

    Connections {
        target: Paths
        function onRepoChanged() { root._start(); }
    }
}
