// Runs `modern update` / `modern mirrors` in Service-owned processes.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property bool running: false
    property bool mirrorsRunning: false
    property string log: ""
    property string step: ""
    property bool open: false
    property real progress: -1

    readonly property bool indeterminate: root.running && root.progress < 0

    Process {
        id: proc
        running: false
        stdout: SplitParser {
            onRead: line => root._append(line)
        }
        stderr: SplitParser {
            onRead: line => root._append(line)
        }
        onExited: (code) => {
            root.running = false;
            root.progress = code === 0 ? 1 : -1;
            if (code !== 0)
                Logger.error("Update", "modern update exited " + code);
        }
    }

    Process {
        id: mirrorsProc
        running: false
        stdout: SplitParser {
            onRead: line => root._append(line)
        }
        stderr: SplitParser {
            onRead: line => root._append(line)
        }
        onExited: root.mirrorsRunning = false
    }

    function start() {
        if (root.running)
            return;
        root.open = true;
        root.log = "";
        root.step = I18n.t("settings.updateStep");
        root.progress = -1;
        root.running = true;
        proc.command = [Quickshell.env("HOME") + "/modern_dotfile/scripts/modern", "update"];
        proc.running = true;
    }

    function refreshMirrors() {
        if (root.mirrorsRunning || root.running)
            return;
        root.open = true;
        root.log = "";
        root.step = I18n.t("settings.mirrorsUpdate");
        root.mirrorsRunning = true;
        mirrorsProc.command = [Quickshell.env("HOME") + "/modern_dotfile/scripts/modern", "mirrors"];
        mirrorsProc.running = true;
    }

    function close() {
        root.open = false;
    }

    function _append(line: string) {
        const t = String(line || "").trim();
        if (t.length === 0)
            return;
        root.log += t + "\n";
        root.step = t;
        const low = t.toLowerCase();
        if (low.indexOf("snapshot") !== -1)
            root.progress = 0.2;
        else if (low.indexOf("::") !== -1 || low.indexOf("yay") !== -1)
            root.progress = -1;
    }
}
