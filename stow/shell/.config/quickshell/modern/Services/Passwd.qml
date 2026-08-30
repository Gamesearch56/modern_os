// Local accounts for Settings > Users. Human getent lists; chfn for
// the session name; passwd/su in the configured terminal. Group
// mutation uses gated modern-usersd only when that binary exists.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    readonly property string loginName: Quickshell.env("USER") || ""
    property bool watching: false
    property string lastError: ""
    property bool helperPresent: false
    property var users: []
    property var others: []
    property var groups: []
    property var localGroups: []
    property var _queue: []

    function refresh() {
        if (!root.watching)
            return;
        snapProc.running = true;
        myGroupsProc.running = true;
        helperProc.running = true;
    }

    function setDisplayName(name: string) {
        const n = String(name || "").trim();
        if (n.length === 0)
            return;
        nameProc.command = ["chfn", "-f", n];
        nameProc.running = true;
    }

    function setPassword() {
        Apps.runInTerminal(["passwd"]);
    }

    function openLogin(login: string) {
        const u = String(login || "");
        if (u.length > 0)
            Apps.runInTerminal(["su", "-", u]);
    }

    function setUserGroups(login: string, names: var): bool {
        if (!root.helperPresent) {
            root.lastError = "gated";
            return false;
        }
        const u = String(login || "");
        const list = names || [];
        if (!u.length || list.length === 0)
            return false;
        root._queue = root._queue.concat([{ login: u, groups: list }]);
        root._drain();
        return true;
    }

    function setGroupMembers(groupName: string, memberLogins: var): bool {
        const g = String(groupName || "");
        const want = memberLogins || [];
        const people = root.users || [];
        for (let i = 0; i < people.length; i++) {
            const u = people[i];
            const has = (u.groups || []).indexOf(g) !== -1;
            const should = want.indexOf(u.login) !== -1;
            if (has === should)
                continue;
            let next = (u.groups || []).filter(n => n !== g);
            if (should)
                next.push(g);
            if (next.length === 0)
                next = [u.login];
            if (!root.setUserGroups(u.login, next))
                return false;
        }
        return true;
    }

    function _drain() {
        if (mutateProc.running)
            return;
        const q = root._queue || [];
        if (q.length === 0) {
            root.refresh();
            return;
        }
        const job = q[0];
        root._queue = q.slice(1);
        const body = JSON.stringify({ action: "groups", username: job.login, groups: job.groups });
        mutateProc.command = ["sh", "-c", "printf '%s\\n' \"$1\" | pkexec /usr/local/bin/modern-usersd", "usersd", body];
        mutateProc.running = true;
    }

    function _parseSnap(text: string) {
        const parts = (text || "").split("\n---\n");
        const people = [];
        const passLines = (parts[0] || "").trim().split("\n");
        for (let i = 0; i < passLines.length; i++) {
            const p = passLines[i].split("\t");
            if (p.length < 6)
                continue;
            const uid = Number(p[1]);
            const gecos = (p[3] || "").split(",")[0];
            const shell = p[5] || "";
            const home = p[4] || "";
            if (uid < 1000 || uid >= 60000)
                continue;
            if (shell.indexOf("nologin") !== -1 || shell.indexOf("false") !== -1)
                continue;
            if (home.indexOf("/run/") === 0 || gecos === "Dynamic User")
                continue;
            people.push({ login: p[0], uid: uid, gid: Number(p[2]), gecos: gecos, home: home, shell: shell, groups: [] });
        }
        const table = [];
        const gLines = (parts[1] || "").trim().split("\n");
        for (let i = 0; i < gLines.length; i++) {
            const p = gLines[i].split("\t");
            if (!p[0])
                continue;
            table.push({
                name: p[0],
                gid: Number(p[1] || 0),
                members: (p[2] || "").split(",").map(s => s.trim()).filter(s => s.length > 0)
            });
        }
        const byGid = ({});
        for (let i = 0; i < table.length; i++)
            byGid[table[i].gid] = table[i];
        for (let i = 0; i < people.length; i++) {
            const names = [];
            const primary = byGid[people[i].gid];
            if (primary)
                names.push(primary.name);
            for (let j = 0; j < table.length; j++) {
                if ((table[j].members || []).indexOf(people[i].login) !== -1 && names.indexOf(table[j].name) === -1)
                    names.push(table[j].name);
            }
            people[i].groups = names;
        }
        root.users = people;
        root.others = people.filter(u => u.login !== root.loginName);
        const logins = people.map(u => u.login);
        const shown = [];
        for (let i = 0; i < table.length; i++) {
            const g = table[i];
            const mem = (g.members || []).slice();
            for (let j = 0; j < people.length; j++) {
                if (people[j].gid === g.gid && mem.indexOf(people[j].login) === -1)
                    mem.push(people[j].login);
            }
            const humans = mem.filter(n => logins.indexOf(n) !== -1);
            if (g.gid >= 1000 || humans.length > 0)
                shown.push({ name: g.name, gid: g.gid, members: humans });
        }
        root.localGroups = shown;
    }

    Process {
        id: helperProc
        command: ["sh", "-c", "test -x /usr/local/bin/modern-usersd && echo 1 || echo 0"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.helperPresent = this.text.trim() === "1"
        }
    }

    Process {
        id: snapProc
        command: ["sh", "-c", "getent passwd | awk -F: 'BEGIN{OFS=\"\\t\"} $3>=1000 && $3<60000 {print $1,$3,$4,$5,$6,$7}'; echo ---; getent group | awk -F: 'BEGIN{OFS=\"\\t\"} {print $1,$3,$4}'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parseSnap(this.text)
        }
    }

    Process {
        id: myGroupsProc
        command: ["id", "-nG"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.groups = this.text.trim().split(/\s+/).filter(s => s.length > 0)
        }
    }

    Process {
        id: nameProc
        running: false
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim().length > 0)
                    Logger.error("Passwd", this.text.trim());
            }
        }
        onRunningChanged: {
            if (!nameProc.running)
                root.refresh();
        }
    }

    Process {
        id: mutateProc
        running: false
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim().length > 0)
                    Logger.error("Passwd", this.text.trim());
            }
        }
        onRunningChanged: {
            if (!mutateProc.running)
                root._drain();
        }
    }

    onWatchingChanged: {
        if (root.watching)
            root.refresh();
    }
}
