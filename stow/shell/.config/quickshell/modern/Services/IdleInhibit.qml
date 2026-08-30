// Holds a systemd-inhibit idle lock for caffeine, fullscreen, or media.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property bool caffeine: false
    property bool active: false

    Process {
        id: inhibit
        command: ["systemd-inhibit", "--what=idle", "--who=modern", "--why=Idle inhibit", "--mode=block", "sleep", "infinity"]
        running: root.active
    }

    function setActive(on: bool) {
        root.active = on;
    }

    function toggle() {
        root.caffeine = !root.caffeine;
    }
}
