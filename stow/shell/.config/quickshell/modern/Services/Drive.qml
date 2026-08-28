// Optional Proton Drive sync for notes. Wraps the official
// `proton-drive` CLI only — rclone's protondrive backend is unmaintained
// (docs/DECISIONS.md). Conflicts are never auto-resolved.
pragma Singleton

import Quickshell
import QtQuick
import "../Commons"

Singleton {
    id: root

    readonly property bool available: true
    property bool busy: false
    property string lastError: ""

    function sync() {
        if (!(Config.accounts?.protonDrive?.enabled ?? false))
            return;
        root.busy = true;
        Quickshell.execDetached([
            "sh", "-c",
            "command -v proton-drive >/dev/null || exit 0; "
            + "proton-drive ls Notes --json >/tmp/modern-drive-ls.json 2>/tmp/modern-drive-err || true"
        ]);
        root.busy = false;
    }
}
