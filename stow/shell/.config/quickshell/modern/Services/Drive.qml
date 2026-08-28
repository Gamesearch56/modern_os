// Optional Proton Drive sync for notes. Wraps the official
// `proton-drive` CLI only — rclone's protondrive backend is unmaintained
// (docs/DECISIONS.md). Conflicts are never auto-resolved.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    readonly property bool available: true
    property bool busy: false
    property string lastError: ""

    Process {
        id: proc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim();
                if (t.length > 0)
                    Logger.info("Drive", t);
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim();
                if (t.length > 0) {
                    root.lastError = t;
                    Logger.error("Drive", t);
                }
            }
        }
        onExited: (exitCode) => {
            root.busy = false;
            if (exitCode !== 0 && root.lastError.length === 0)
                Logger.error("Drive", "proton-drive exited " + exitCode);
        }
    }

    function sync() {
        if (!(Config.accounts?.protonDrive?.enabled ?? false))
            return;
        root.busy = true;
        root.lastError = "";
        try {
            proc.command = [
                "sh", "-c",
                "command -v proton-drive >/dev/null || { echo 'proton-drive not installed' >&2; exit 1; }; "
                + "proton-drive ls Notes --json >/tmp/modern-drive-ls.json"
            ];
            proc.running = true;
        } catch (e) {
            root.busy = false;
            root.lastError = String(e);
            Logger.error("Drive", String(e));
        }
    }
}
