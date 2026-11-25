// Unprivileged self-service for the session account. chfn as $USER
// so a standard account can set its display name without pkexec.
import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Item {
    id: root
    visible: false
    width: 0
    height: 0

    property var host: null
    property string _gecos: ""
    property bool canSetGecos: false

    FileView {
        path: "/etc/login.defs"
        watchChanges: true
        printErrors: false
        onLoaded: {
            const t = text() || "";
            const m = t.match(/^\s*CHFN_RESTRICT\s+"?([A-Za-z]+)"?/m);
            root.canSetGecos = !!(m && m[1].indexOf("f") !== -1);
        }
        onLoadFailed: root.canSetGecos = false
    }

    function applyGecos(name: string) {
        const g = String(name || "").trim();
        if (!root.host || !root.host.gecosOk(g)) {
            if (root.host)
                root.host.lastError = I18n.t("settings.users.invalid");
            return;
        }
        if (root.host.running)
            return;
        root._gecos = g;
        root.host.running = true;
        root.host.lastError = "";
        proc.running = false;
        Qt.callLater(() => {
            proc.running = true;
        });
    }

    Process {
        id: proc
        command: ["chfn", "-f", root._gecos]
        running: false
        stderr: StdioCollector {
            id: err
        }
        onExited: (code) => {
            proc.running = false;
            if (root.host)
                root.host.running = false;
            if (code !== 0) {
                if (root.host)
                    root.host.lastError = I18n.t("settings.users.failed");
                return;
            }
            if (root.host && root.host.watching)
                root.host.refresh();
        }
    }
}
