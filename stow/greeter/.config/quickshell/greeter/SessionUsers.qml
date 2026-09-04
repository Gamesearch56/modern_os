// Human login names for the greeter select. System accounts stay out.
import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root

    property var model: []

    Process {
        id: passwdProc
        command: ["getent", "passwd"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root._parse(String(this.text || ""))
        }
    }

    function _parse(raw: string) {
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
                titleValue: gecos.length > 0 ? gecos : login
            });
        }
        root.model = out;
    }
}
