// Boot and journal snapshot for Settings > System. Owns systemd-analyze
// and journalctl; the view only binds properties. The timer runs only
// while a consumer sets `watching` (the diagnostics embed is visible).
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property bool watching: false
    property string bootSeconds: ""
    property string journalErrors: ""

    function refresh() {
        bootProc.running = true;
        journalProc.running = true;
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
            onStreamFinished: root.bootSeconds = this.text.trim()
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (root.bootSeconds.length === 0 && this.text.trim().length > 0)
                    root.bootSeconds = this.text.trim();
            }
        }
    }

    Process {
        id: journalProc
        command: ["journalctl", "-p", "err", "-b", "-n", "30", "--no-pager"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.journalErrors = this.text.trim()
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (root.journalErrors.length === 0 && this.text.trim().length > 0)
                    root.journalErrors = this.text.trim();
            }
        }
    }

    Timer {
        interval: Config.widgets.performance?.pollIntervalMs ?? 2000
        running: root.watching
        repeat: true
        onTriggered: root.refresh()
    }
}
