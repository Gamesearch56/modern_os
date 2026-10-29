// Allowlisted disk cleanup. One pkexec of storage-clean.sh. Never
// deletes documents, photos, or games — only caches, unused packages,
// and logs older than 14 days.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property string phase: ""
    property string step: ""
    property string error: ""
    property real saved: 0
    property bool running: false

    readonly property bool open: root.phase.length > 0

    Process {
        id: proc
        command: ["pkexec", Paths.script("storage-clean.sh")]
        running: false
        stdout: SplitParser {
            onRead: (line) => root._line(String(line || ""))
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const t = String(this.text || "").trim();
                if (t.length && root.running)
                    root.error = t.split("\n").pop();
            }
        }
        onExited: (code) => {
            root.running = false;
            if (code !== 0 && root.saved <= 0 && !root.error.length)
                root.error = I18n.t("settings.storage.cleanFailed");
            root.phase = "done";
            if (code === 0)
                StorageUsage.refresh();
        }
    }

    function ask() {
        if (root.running)
            return;
        root.phase = "ask";
        root.step = "";
        root.error = "";
        root.saved = 0;
    }

    function cancel() {
        if (root.running)
            return;
        root.phase = "";
        root.step = "";
        root.error = "";
        root.saved = 0;
    }

    function start() {
        if (root.running || root.phase !== "ask")
            return;
        root.phase = "run";
        root.running = true;
        root.error = "";
        root.saved = 0;
        root.step = I18n.t("settings.storage.cleanStart");
        proc.running = true;
    }

    function _line(line: string) {
        const t = String(line || "").trim();
        if (t.indexOf("step ") === 0) {
            root.step = root._stepLabel(t.slice(5));
            return;
        }
        if (t.indexOf("done ") === 0) {
            const n = Number(t.slice(5));
            root.saved = n > 0 ? n : 0;
        }
    }

    function _stepLabel(id: string): string {
        switch (String(id || "")) {
        case "thumbnails":
            return I18n.t("settings.storage.cleanThumbnails");
        case "gpu":
            return I18n.t("settings.storage.cleanGpu");
        case "fonts":
            return I18n.t("settings.storage.cleanFonts");
        case "packages":
            return I18n.t("settings.storage.cleanPackages");
        case "journal":
            return I18n.t("settings.storage.cleanJournal");
        default:
            return I18n.t("settings.storage.cleanStart");
        }
    }
}
