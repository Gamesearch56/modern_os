// Human login names for the greeter select. System accounts stay out.
// FileView /etc/passwd is world-readable; JSON is a snapshot from kiosk.
// Do not name this property `model` — Variants delegates have treated
// `users: users` as a self-binding and left the select empty.
import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root

    property var accounts: []

    function _apply(rows: var) {
        const src = rows || [];
        const n = src.length;
        if (typeof n !== "number" || n <= 0)
            return;
        const out = [];
        for (let i = 0; i < n; i++) {
            const r = src[i] || ({});
            const login = String(r.value || "");
            if (!login.length)
                continue;
            out.push({
                value: login,
                titleValue: String(r.titleValue || login),
                home: String(r.home || "")
            });
        }
        if (!out.length)
            return;
        root.accounts = out;
    }

    function _parseJson(raw: string) {
        try {
            root._apply(JSON.parse(raw || "[]"));
        } catch (e) {
            /* keep whatever already loaded */
        }
    }

    function _parsePasswd(raw: string) {
        const skipUser = ({
            greeter: true,
            nobody: true,
            nfsnobody: true
        });
        const skipShell = ({
            "/usr/bin/nologin": true,
            "/sbin/nologin": true,
            "/usr/sbin/nologin": true,
            "/bin/false": true,
            "/usr/bin/false": true,
            "/sbin/false": true
        });
        const lines = (raw || "").split("\n");
        const out = [];
        for (let i = 0; i < lines.length; i++) {
            const parts = lines[i].split(":");
            if (parts.length < 7)
                continue;
            const login = parts[0];
            const uid = Number(parts[2]);
            const shell = parts[6] || "";
            if (!login.length || skipUser[login])
                continue;
            if (!(uid >= 1000 && uid < 65534))
                continue;
            if (skipShell[shell] || shell.indexOf("nologin") >= 0)
                continue;
            const gecos = (parts[4] || "").split(",")[0].trim();
            out.push({
                value: login,
                titleValue: gecos.length > 0 ? gecos : login,
                home: parts[5] || ""
            });
        }
        root._apply(out);
    }

    FileView {
        path: "/etc/passwd"
        preload: true
        watchChanges: true
        printErrors: false
        onLoaded: root._parsePasswd(String(text() || ""))
        onFileChanged: reload()
    }

    FileView {
        path: "/var/lib/modern/session/users.json"
        preload: true
        watchChanges: true
        printErrors: false
        onLoaded: root._parseJson(String(text() || ""))
        onFileChanged: reload()
    }

    FileView {
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "") + "/modern-users.json"
        preload: true
        watchChanges: true
        printErrors: false
        onLoaded: root._parseJson(String(text() || ""))
        onFileChanged: reload()
    }

    Process {
        id: passwdProc
        command: ["/usr/bin/getent", "passwd"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (!(root.accounts && root.accounts.length))
                    root._parsePasswd(String(this.text || ""));
            }
        }
    }

    Timer {
        interval: 80
        running: true
        repeat: false
        onTriggered: passwdProc.running = true
    }
}
