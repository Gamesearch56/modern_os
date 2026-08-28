// Runs `modern update` in a Service-owned process.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property bool running: false
    property string log: ""
    property bool open: false

    Process {
        id: proc
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.log += this.text
        }
        stderr: StdioCollector {
            onStreamFinished: root.log += this.text
        }
        onExited: (code) => {
            root.running = false;
            if (code !== 0)
                Logger.error("Update", "modern update exited " + code);
        }
    }

    function start() {
        if (root.running)
            return;
        root.open = true;
        root.log = "";
        root.running = true;
        proc.command = [Quickshell.env("HOME") + "/modern_dotfile/scripts/modern", "update"];
        proc.running = true;
    }

    function close() {
        root.open = false;
    }
}
