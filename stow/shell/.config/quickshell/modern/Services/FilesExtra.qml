// Extra file windows. Each one is its own file manager process so it
// keeps a folder without moving the window that is already open.
pragma Singleton

import Quickshell
import QtQuick
import "../Commons"

Singleton {
    id: root

    function open(path: string) {
        const next = String(path || "");
        if (!next.length)
            return;
        Quickshell.execDetached([Paths.script("files-window.sh"), next]);
    }
}
