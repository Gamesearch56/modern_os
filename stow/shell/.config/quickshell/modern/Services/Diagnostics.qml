// Boot snapshot and machine identity for Settings > System.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property bool watching: false
    property string bootSeconds: ""
    property real bootChart: 0
    property string hardware: ""
    property string software: ""

    function refresh() {
        bootProc.running = true;
        hwProc.running = true;
        swProc.running = true;
    }

    onWatchingChanged: {
        if (root.watching)
            root.refresh();
    }

    Process {
        id: bootProc
        command: ["systemd-analyze"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.bootSeconds = this.text.trim();
                const m = this.text.match(/([0-9.]+)s/);
                root.bootChart = m ? Math.min(1, Number(m[1]) / 30) : 0;
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (root.bootSeconds.length === 0 && this.text.trim().length > 0)
                    root.bootSeconds = this.text.trim();
            }
        }
    }

    Process {
        id: hwProc
        command: ["sh", "-c", "lscpu 2>/dev/null | awk -F: '/Model name/{print $2; exit}'; echo; cat /sys/class/dmi/id/product_name 2>/dev/null; echo; free -h | awk 'NR==2{print}'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.hardware = this.text.trim()
        }
    }

    Process {
        id: swProc
        command: ["sh", "-c", ". /etc/os-release; echo \"$PRETTY_NAME\"; uname -r; command -v hyprland >/dev/null && hyprland --version 2>/dev/null | head -1"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.software = this.text.trim()
        }
    }
}
