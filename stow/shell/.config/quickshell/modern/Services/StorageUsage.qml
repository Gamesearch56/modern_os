// Category disk use for Settings → Storage. Nothing runs until the
// user asks; leaving the page stops a scan that is still walking disks.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property bool watching: false
    property bool running: false
    property bool measured: false
    property real games: 0
    property real files: 0
    property real apps: 0
    property real cache: 0
    property real backups: 0
    property real models: 0

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

    onWatchingChanged: {
        if (!root.watching && proc.running)
            proc.running = false;
    }

    function start() {
        root.refresh();
    }

    function refresh() {
        if (proc.running)
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
            root.models = Number(j.models) || 0;
            root.measured = true;
        } catch (e) {
            Logger.warn("StorageUsage", String(e));
        }
    }
}
