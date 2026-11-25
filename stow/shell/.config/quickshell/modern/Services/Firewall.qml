// Live UFW. Status is unprivileged (`ufw-status.sh`). Enable/disable
// is one pkexec of `ufw-apply.sh` (defaults + enable in that process).
// Rule add/delete still pkexec /usr/bin/ufw with an argv allowlist.
// Comment edits pkexec `ufw-comment.sh` so the tuple is not deleted.
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
    property bool _closingMut: false
    property bool _listLive: false

    readonly property bool active: root.status === "active"
    readonly property bool present: root.status === "active" || root.status === "inactive"

    FirewallParse { id: rules }

    Process {
        id: listProc
        command: [Paths.script("ufw-status.sh")]
        running: false
        stdout: StdioCollector {
            id: listOut
            onStreamFinished: root._applyList(listOut.text)
        }
        onExited: (code) => {
            if (!root._listLive)
                return;
            root._listLive = false;
            if (code !== 0 && root.error.length === 0)
                root.error = I18n.t("settings.firewall.failed");
        }
    }

    Process {
        id: mutProc
        running: false
        stderr: StdioCollector {
            id: mutErr
        }
        onExited: (code) => {
            // running=false inside exited re-enters this handler and
            // treats a finished enable as a failure.
            if (root._closingMut)
                return;
            root._closingMut = true;
            mutProc.running = false;
            root._closingMut = false;
            root._mutDone(code);
        }
    }

    onWatchingChanged: {
        if (root.watching)
            root.refresh();
        else
            listProc.running = false;
    }

    function refresh() {
        root._reload(true);
    }

    // clearError is false after a failed enable so the ufw message
    // stays up. The status read exits 0 even when the firewall is off,
    // which would otherwise wipe the failure.
    function _reload(clearError: bool) {
        if (!root.watching)
            return;
        if (clearError)
            root.error = "";
        root._listLive = false;
        listProc.running = false;
        Qt.callLater(() => {
            if (!root.watching)
                return;
            root._listLive = true;
            listProc.running = true;
        });
    }

    function _mutDone(code: int) {
        const err = String(mutErr.text || "").trim();
        if (code !== 0) {
            root._queue = [];
            root.running = false;
            root.mutating = "";
            root.error = err.length ? err : I18n.t("settings.firewall.failed");
            root._reload(false);
            return;
        }
        root.error = "";
        Qt.callLater(root._kick);
    }

    function setEnabled(on) {
        if (root.running || root.status === "missing")
            return;
        const apply = Paths.script("ufw-apply.sh");
        root._start(on ? "enable" : "disable", [["pkexec", apply, on ? "enable" : "disable"]]);
    }

    function add(policy, fields) {
        const argv = root._addArgv(policy, fields);
        if (!argv)
            return;
        root._start("add", [argv]);
    }

    function remove(num) {
        const n = String(num || "").replace(/[^0-9]/g, "");
        if (!n || root.running || !root.active)
            return;
        if (!root._hasNumber(n)) {
            root.error = I18n.t("settings.firewall.stale");
            return;
        }
        root._start("delete", [["pkexec", root.bin, "--force", "delete", n]]);
    }

    function setComment(num, text) {
        const n = String(num || "").replace(/[^0-9]/g, "");
        const c = String(text || "").trim();
        if (!n || root.running || !root.active)
            return;
        if (!root._hasNumber(n)) {
            root.error = I18n.t("settings.firewall.stale");
            return;
        }
        if (!rules.commentOk(c)) {
            root.error = I18n.t("settings.firewall.invalid");
            return;
        }
        const argv = ["pkexec", Paths.script("ufw-comment.sh"), n];
        if (c.length)
            argv.push(c);
        root._start("comment", [argv]);
    }

    function portOk(s: var): bool { return rules.portOk(s); }
    function fromOk(s: var): bool { return rules.fromOk(s); }
    function commentOk(s: var): bool { return rules.commentOk(s); }

    function _start(kind: string, cmds: var) {
        if (root.running || !Array.isArray(cmds) || cmds.length === 0)
            return;
        root.running = true;
        root.mutating = kind;
        root.error = "";
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
        mutProc.running = false;
        mutProc.command = next;
        Qt.callLater(() => {
            if (root.running)
                mutProc.running = true;
        });
    }

    function _addArgv(policy, fields) {
        if (root.running || !root.active)
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
