// timedatectl wrapper. Settings never spawns this — timezone display
// and optional set stay in Services (polkit may prompt on write).
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property string timezone: ""

    Process {
        id: readProc
        command: ["timedatectl", "show", "-p", "Timezone", "--value"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.timezone = this.text.trim()
        }
    }

    Process {
        id: setProc
        running: false
        stderr: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim();
                if (t.length > 0)
                    Logger.error("Locale", t);
            }
        }
        onExited: readProc.running = true
    }

    function refresh() {
        readProc.running = true;
    }

    function setTimezone(id: string) {
        if (!id || id.length === 0)
            return;
        setProc.command = ["timedatectl", "set-timezone", id];
        setProc.running = true;
    }

    Component.onCompleted: root.refresh()
}
