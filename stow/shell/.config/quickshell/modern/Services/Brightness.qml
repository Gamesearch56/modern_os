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
    property bool _loggedMissing: false

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
                } else if (!root._loggedMissing) {
                    root._loggedMissing = true;
                    Logger.warn("Brightness", "brightnessctl returned no usable output");
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim();
                if (t.length > 0)
                    Logger.warn("Brightness", t);
            }
        }
    }

    Process {
        id: writeProc
        command: ["brightnessctl", "set", "100%"]
        stderr: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim();
                if (t.length > 0)
                    Logger.error("Brightness", t);
            }
        }
        onExited: (exitCode) => {
            if (exitCode !== 0)
                Logger.error("Brightness", "brightnessctl set exited " + exitCode);
        }
    }

    Timer {
        interval: Motion.extraLong() * 8
        running: root.watching && root.available
        repeat: true
        onTriggered: readProc.running = true
    }

    Component.onCompleted: readProc.running = true

    function setPercent(value: int) {
        try {
            const v = Math.max(1, Math.min(100, Math.round(value)));
            root.percent = v;
            writeProc.command = ["brightnessctl", "set", v + "%"];
            writeProc.running = true;
        } catch (e) {
            Logger.error("Brightness", String(e));
        }
    }

    function adjust(delta: int) {
        root.setPercent(root.percent + delta);
    }
}
