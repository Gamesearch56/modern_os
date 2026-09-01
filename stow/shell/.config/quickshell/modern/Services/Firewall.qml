// Live UFW via pkexec /usr/bin/ufw. Argv allowlist only; no shell, no reset.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    readonly property string bin: "/usr/bin/ufw"
    property bool watching: false
    property bool running: false
    property string status: "unknown"
    property string error: ""
    property string mutating: ""
    property var allow: []
    property var deny: []
    property var _queue: []
    property string _stderr: ""

    readonly property bool active: root.status === "active"
    readonly property bool present: root.status === "active" || root.status === "inactive"

    FirewallParse { id: rules }

    Process {
        id: probeProc
        command: ["/usr/bin/test", "-x", root.bin]
        running: false
        onExited: (code) => {
            if (code !== 0) {
                root.status = "missing";
                root.allow = [];
                root.deny = [];
                return;
            }
            if (root.status === "missing" || root.status === "unknown")
                root.status = "inactive";
            if (root.watching)
                listProc.running = true;
        }
    }

    Process {
        id: listProc
        command: ["pkexec", root.bin, "status", "numbered"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._applyList(this.text)
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const t = String(this.text || "").trim();
                if (t.length)
                    root.error = t;
            }
        }
        onExited: (code) => {
            if (code !== 0 && root.error.length === 0)
                root.error = I18n.t("settings.firewall.failed");
            if (code === 0)
                root.error = "";
        }
    }

    Process {
        id: mutProc
        running: false
        stderr: StdioCollector {
            onStreamFinished: root._stderr = String(this.text || "").trim()
        }
        onExited: (code) => {
            if (code !== 0) {
                root._queue = [];
                root.running = false;
                root.mutating = "";
                root.error = root._stderr.length ? root._stderr : I18n.t("settings.firewall.failed");
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
    }

    function refresh() {
        if (!root.watching)
            return;
        root.error = "";
        probeProc.running = true;
    }

    function setEnabled(on) {
        if (root.running || root.status === "missing")
            return;
        if (on) {
            root._start("enable", [
                ["pkexec", root.bin, "default", "deny", "incoming"],
                ["pkexec", root.bin, "default", "allow", "outgoing"],
                ["pkexec", root.bin, "default", "deny", "routed"],
                ["pkexec", root.bin, "--force", "enable"]
            ]);
            return;
        }
        root._start("disable", [["pkexec", root.bin, "disable"]]);
    }

    function add(policy, fields) {
        const argv = root._addArgv(policy, fields);
        if (!argv)
            return;
        root._start("add", [argv]);
    }

    function remove(num) {
        const n = String(num || "").replace(/[^0-9]/g, "");
        if (!n || root.running || root.status === "missing")
            return;
        if (!root._hasNumber(n)) {
            root.error = I18n.t("settings.firewall.stale");
            return;
        }
        root._start("delete", [["pkexec", root.bin, "--force", "delete", n]]);
    }

    function portOk(s): bool { return rules.portOk(s); }
    function fromOk(s): bool { return rules.fromOk(s); }
    function commentOk(s): bool { return rules.commentOk(s); }

    function _start(kind: string, cmds: var) {
        if (root.running || !Array.isArray(cmds) || cmds.length === 0)
            return;
        root.running = true;
        root.mutating = kind;
        root.error = "";
        root._stderr = "";
        root._queue = cmds;
        root._kick();
    }

    function _kick() {
        if (root._queue.length === 0) {
            root.running = false;
            root.mutating = "";
            if (root.watching)
                root.refresh();
            return;
        }
        const next = root._queue[0];
        root._queue = root._queue.slice(1);
        mutProc.command = next;
        mutProc.running = true;
    }

    function _addArgv(policy, fields) {
        if (root.running || root.status === "missing")
            return null;
        const p = String(policy || "");
        const f = fields || ({});
        const port = String(f.port || "").trim();
        const proto = String(f.proto || "").trim().toLowerCase();
        const dir = String(f.direction || "in").trim().toLowerCase();
        const from = String(f.from || "").trim();
        const comment = String(f.comment || "").trim();
        const bad = (p !== "allow" && p !== "deny") || !rules.portOk(port) || !rules.fromOk(from) || !rules.commentOk(comment) || (proto !== "" && proto !== "tcp" && proto !== "udp") || (dir !== "in" && dir !== "out");
        if (bad) {
            root.error = I18n.t("settings.firewall.invalid");
            return null;
        }
        const argv = ["pkexec", root.bin, p, dir];
        if (proto.length)
            argv.push("proto", proto);
        if (from.length)
            argv.push("from", from);
        argv.push("to", "any", "port", port);
        if (comment.length)
            argv.push("comment", comment);
        return argv;
    }

    function _hasNumber(n: string): bool {
        const lists = [root.allow, root.deny];
        for (let i = 0; i < lists.length; i++) {
            const rows = lists[i] || [];
            for (let j = 0; j < rows.length; j++) {
                if (String(rows[j].number || "") === n)
                    return true;
            }
        }
        return false;
    }

    function _applyList(text: string) {
        const out = rules.parseStatus(text);
        if (out.status.length)
            root.status = out.status;
        root.allow = out.allow;
        root.deny = out.deny;
    }
}
