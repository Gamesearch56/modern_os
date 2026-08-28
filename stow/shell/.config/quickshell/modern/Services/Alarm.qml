// One countdown timer. Starting another requires cancel of the current.
pragma Singleton

import Quickshell
import QtQuick
import "../Commons"

Singleton {
    id: root

    property int remainingSec: 0
    property int durationMin: 10
    property bool running: false
    property bool dialogOpen: false

    signal fired()

    Timer {
        interval: 1000
        running: root.running && root.remainingSec > 0
        repeat: true
        onTriggered: {
            root.remainingSec -= 1;
            if (root.remainingSec <= 0) {
                root.running = false;
                root.remainingSec = 0;
                root.fired();
                Quickshell.execDetached(["paplay", "/usr/share/sounds/freedesktop/stereo/complete.oga"]);
            }
        }
    }

    function start(minutes: int) {
        const m = Math.max(1, minutes);
        root.durationMin = m;
        root.remainingSec = m * 60;
        root.running = true;
        root.dialogOpen = false;
    }

    function cancel() {
        root.running = false;
        root.remainingSec = 0;
        root.dialogOpen = false;
    }

    function toggleDialog() {
        if (root.running)
            return;
        root.dialogOpen = !root.dialogOpen;
    }
}
