// True while a program is starting and its window is not on screen yet.
// The compositor cursor is swapped by cursor-busy.sh; shell surfaces
// paint the same watch so the dock does not keep its own arrow.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool busy: false

    IpcHandler {
        target: "launchcursor"
        function begin() { root.busy = true; }
        function end() { root.busy = false; }
    }
}
