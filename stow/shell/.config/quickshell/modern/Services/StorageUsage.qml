// Category disk use for Settings → Storage. Unprivileged du/pacman
// via storage-usage.sh; runs while the page is visible, not on a 5s poll.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property bool watching: false
    property bool running: false
    property real games: 0
    property real files: 0
    property real apps: 0
    property real cache: 0
    property real backups: 0

    Process {
        id: proc
        command: [Paths.script("storage-usage.sh")]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._apply(this.text)
        }
        onRunningChanged: {
            if (proc.running)
                root.running = true;
        }
        onExited: root.running = false
    }

    Timer {
        interval: 120000
        running: root.watching
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    onWatchingChanged: {
        if (!root.watching)
            proc.running = false;
    }

    function refresh() {
        if (!root.watching)
            return;
        proc.running = true;
    }

    function _apply(raw: string) {
        try {
            const j = JSON.parse(String(raw || "").trim() || "{}");
            root.games = Number(j.games) || 0;
            root.files = Number(j.files) || 0;
            root.apps = Number(j.apps) || 0;
            root.cache = Number(j.cache) || 0;
            root.backups = Number(j.backups) || 0;
        } catch (e) {
            Logger.warn("StorageUsage", String(e));
        }
    }
}
