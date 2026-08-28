// Display brightness. Uses brightnessctl via a Process because there
// is no D-Bus standard that covers both internal panels and DDC
// external monitors. The widget only calls setPercent / adjust.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property bool watching: false
    property int percent: 100
    property bool available: false

    Process {
        id: readProc
        command: ["brightnessctl", "-m"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const line = this.text.trim().split("\n")[0] ?? "";
                const parts = line.split(",");
                if (parts.length >= 4) {
                    root.percent = parseInt(parts[3], 10);
                    root.available = true;
                }
            }
        }
    }

    Process {
        id: writeProc
        command: ["brightnessctl", "set", "100%"]
    }

    Timer {
        interval: Motion.extraLong() * 8
        running: root.watching && root.available
        repeat: true
        onTriggered: readProc.running = true
    }

    Component.onCompleted: readProc.running = true

    function setPercent(value: int) {
        const v = Math.max(1, Math.min(100, Math.round(value)));
        root.percent = v;
        writeProc.command = ["brightnessctl", "set", v + "%"];
        writeProc.running = true;
    }

    function adjust(delta: int) {
        root.setPercent(root.percent + delta);
    }
}
