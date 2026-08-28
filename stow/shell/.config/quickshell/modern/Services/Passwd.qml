// Display name (chfn) and password (pkexec chpasswd). Never logs secrets.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property string lastError: ""
    property var users: []
    property var groups: []

    Process {
        id: usersProc
        command: ["sh", "-c", "getent passwd | awk -F: '$3>=1000 && $3<65534 {print $1 \"\\t\" $5}'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n");
                const out = [];
                for (let i = 0; i < lines.length; i++) {
                    if (!lines[i])
                        continue;
                    const p = lines[i].split("\t");
                    out.push({ login: p[0], gecos: (p[1] || "").split(",")[0] });
                }
                root.users = out;
            }
        }
    }

    Process {
        id: groupsProc
        command: ["sh", "-c", "id -nG"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.groups = this.text.trim().split(/\s+/).filter(s => s.length > 0);
            }
        }
    }

    Process {
        id: nameProc
        running: false
        stderr: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim();
                if (t.length > 0)
                    Logger.error("Passwd", t);
            }
        }
    }

    function setDisplayName(name: string) {
        const n = String(name || "").trim();
        if (n.length === 0)
            return;
        nameProc.command = ["chfn", "-f", n];
        nameProc.running = true;
    }

    function setPassword(next: string) {
        const _ = next;
        Quickshell.execDetached(["kitty", "-e", "passwd"]);
    }
}
