// Holds a systemd-inhibit idle lock while caffeine is on.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property bool active: false

    Process {
        id: inhibit
        command: ["systemd-inhibit", "--what=idle", "--who=modern", "--why=Caffeine", "--mode=block", "sleep", "infinity"]
        running: root.active
    }

    function setActive(on: bool) {
        root.active = on;
    }

    function toggle() {
        root.active = !root.active;
    }
}
