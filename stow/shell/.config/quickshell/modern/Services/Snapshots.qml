// Snapper list/create/delete. Restore stays gated (docs/BACKUP.md).
// Probe and list as the user; create/delete/setup go through pkexec.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property bool watching: false
    property var items: []
    property bool running: false
    property string status: "unknown"
    property string step: ""
    property string mutating: ""
    property string error: ""
    property var _queue: []
    property string _stderr: ""

    readonly property bool ready: root.status === "ready"

    Process {
        id: probeProc
        command: ["sh", "-c", "command -v snapper >/dev/null || { echo missing; exit 0; }; snapper --no-dbus --csvout list-configs 2>/dev/null | awk -F, 'NR>1 {gsub(/\\r/,\"\"); print $1}' | grep -qx root && echo ready || echo unconfigured"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const s = String(this.text || "").trim();
                root.status = (s === "ready" || s === "unconfigured" || s === "missing") ? s : "missing";
                if (root.status === "ready" && root.watching)
                    listProc.running = true;
                else if (root.status !== "ready")
                    root.items = [];
            }
        }
    }

    Process {
        id: listProc
        command: ["sh", "-c", "snapper -c root --jsonout list 2>/dev/null || snapper -c root list --iso 2>/dev/null"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.items = parse.parseList(this.text)
        }
    }

    Process {
        id: mutProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const t = String(this.text || "").trim();
                if (t.length)
                    root._stderr = t;
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const t = String(this.text || "").trim();
                if (t.length)
                    root._stderr = t;
            }
        }
        onExited: (code) => {
            if (code !== 0) {
                root._queue = [];
                root.running = false;
                root.mutating = "";
                root.step = "";
                root.error = root._stderr.length ? root._stderr : I18n.t("cli.snapshotFailed");
                if (root.watching)
                    root.refresh();
                return;
            }
            root.error = "";
            Qt.callLater(root._kick);
        }
    }

    onWatchingChanged: {
        if (root.watching)
            root.refresh();
        else
            root.running = false;
    }

    function refresh() {
        root.error = "";
        probeProc.running = true;
    }

    function setupRoot() {
        if (root.status !== "unconfigured" || root.running)
            return;
        root._start("setup", [[
            "pkexec", Paths.script("snapper-setup.sh")
        ]], I18n.t("settings.backup.settingUp"));
    }

    function create() {
        if (!root.ready || root.running)
            return;
        root._start("create", [[
            "pkexec", "/usr/bin/snapper", "-c", "root", "create",
            "--description", I18n.t("settings.backup.manual")
        ]], I18n.t("settings.backup.creating"));
    }

    function remove(num: string) {
        const n = String(num || "").replace(/[^0-9]/g, "");
        if (!n || n === "0" || root.running)
            return;
        root._start(n, [["pkexec", "/usr/bin/snapper", "-c", "root", "delete", n]], I18n.t("settings.snapshotDelete"));
    }

    function _start(kind: string, cmds: var, step: string) {
        if (root.running || !Array.isArray(cmds) || cmds.length === 0)
            return;
        root.running = true;
        root.mutating = kind;
        root.error = "";
        root._stderr = "";
        root.step = step || "";
        root._queue = cmds;
        root._kick();
    }

    function _kick() {
        if (root._queue.length === 0) {
            root.running = false;
            root.mutating = "";
            root.step = "";
            if (root.watching)
                root.refresh();
            return;
        }
        const next = root._queue[0];
        root._queue = root._queue.slice(1);
        mutProc.command = next;
        mutProc.running = true;
    }

    function formatWhen(raw: string): string {
        return parse.formatWhen(raw);
    }

    SnapshotsParse {
        id: parse
    }
}
