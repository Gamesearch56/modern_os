// `modern mirrors` for Settings → Update (pkexec when not a TTY).
import Quickshell.Io
import QtQuick
import "../Commons"

QtObject {
    id: root

    readonly property bool running: proc.running
    property string error: ""
    signal finished(bool ok)

    function start() {
        if (proc.running)
            return;
        root.error = "";
        proc.command = [Paths.modern, "mirrors"];
        proc.running = true;
    }

    property Process _proc: Process {
        id: proc
        stderr: StdioCollector {
            onStreamFinished: {
                const t = String(this.text || "").trim();
                if (t.length)
                    root.error = t;
            }
        }
        onExited: (code) => root.finished(code === 0)
    }
}
