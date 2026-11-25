// One update check per boot, after the desktop is up and the link is
// usable. A shell reload in the same boot does not ask again.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property bool _idKnown: false
    property bool _stampKnown: false
    property string _bootId: ""
    property string _stamped: ""
    property bool _started: false
    property bool _waiting: false

    readonly property string _stampPath: Paths.stateHome + "/modern/update-boot"

    function arm() {
        root._consider();
    }

    function _consider() {
        if (root._started || !root._idKnown || !root._stampKnown)
            return;
        if (root._bootId.length > 0 && root._bootId === root._stamped)
            return;
        if (!Network.connected)
            return;
        root._started = true;
        delay.restart();
    }

    function _finish() {
        if (!root._waiting || Update.checking)
            return;
        root._waiting = false;
        if (!root._bootId.length)
            return;
        mkdir.running = true;
    }

    FileView {
        id: bootFile
        path: "/proc/sys/kernel/random/boot_id"
        watchChanges: false
        printErrors: false
        onLoaded: {
            root._bootId = String(text() || "").trim();
            root._idKnown = true;
            root._consider();
        }
        onLoadFailed: {
            root._idKnown = true;
            root._consider();
        }
    }

    FileView {
        id: stampFile
        path: root._stampPath
        watchChanges: false
        printErrors: false
        onLoaded: {
            root._stamped = String(text() || "").trim();
            root._stampKnown = true;
            root._consider();
        }
        onLoadFailed: {
            root._stamped = "";
            root._stampKnown = true;
            root._consider();
        }
    }

    Connections {
        target: Network
        function onConnectedChanged() {
            root._consider();
        }
    }

    Timer {
        id: delay
        interval: Motion.bootSettleMs
        repeat: false
        onTriggered: {
            if (Update.running)
                return;
            root._waiting = true;
            Update.refresh();
            if (!Update.checking)
                root._finish();
        }
    }

    Connections {
        target: Update
        function onCheckingChanged() {
            root._finish();
        }
    }

    Process {
        id: mkdir
        command: ["mkdir", "-p", Paths.stateHome + "/modern"]
        onExited: stampFile.setText(root._bootId + "\n")
    }
}
