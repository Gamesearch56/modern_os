// Snapper list/create/delete/restore. Probe and list as the user;
// create/delete/setup/restore go through pkexec.
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

    signal restoreFinished()

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

    function keepLimit(): int {
        const n = Number(Config.backup.keepCount);
        if (n >= 3 && n <= 20)
            return Math.round(n);
        return 8;
    }

    function pruneOn(): bool {
        return Config.backup.pruneEnabled !== false;
    }

    function create() {
        if (!root.ready || root.running)
            return;
        const cmd = [
            "pkexec", Paths.script("snapper-gc.sh"), "create",
            I18n.t("settings.backup.manual")
        ];
        if (root.pruneOn())
            cmd.push(String(root.keepLimit()));
        root._start("create", [cmd], I18n.t("settings.backup.creating"));
    }

    function prune(keep: var) {
        if (!root.ready || root.running || !root.pruneOn())
            return;
        let n = Number(keep);
        if (!(n >= 3 && n <= 20))
            n = root.keepLimit();
        if (root.items.length <= n)
            return;
        root._start("prune", [[
            "pkexec", Paths.script("snapper-gc.sh"), "prune", String(n)
        ]], I18n.t("settings.backup.pruning"));
    }

    function clearAll() {
        if (!root.ready || root.running || root.items.length === 0)
            return;
        root._start("clear", [[
            "pkexec", Paths.script("snapper-gc.sh"), "clear"
        ]], I18n.t("settings.backup.clearing"));
    }

    function restore(num: string) {
        const n = String(num || "").replace(/[^0-9]/g, "");
        if (!n || n === "0" || !root.ready || root.running)
            return;
        root._start("restore", [[
            "pkexec", Paths.script("snapper-restore.sh"), n
        ]], I18n.t("settings.backup.restoring"));
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
            const kind = root.mutating;
            root.running = false;
            root.mutating = "";
            root.step = "";
            if (kind === "restore") {
                root.restoreFinished();
                return;
            }
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
