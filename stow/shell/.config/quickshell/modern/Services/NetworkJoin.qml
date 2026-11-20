// nmcli activate, forget, and disconnect. Quickshell's connectWithPsk
// can store a secret without bringing the network up. A password goes
// to wifi-join.sh on stdin, never argv: /proc/*/cmdline is world-readable.
import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Item {
    id: root

    readonly property bool running: joinProc.running
    readonly property bool waking: wakeProc.running
    // reason: "" on success, else a wifi-join.sh exit code by name.
    signal finished(string op, string ssid, bool ok, string reason)

    property string _op: ""
    property string _ssid: ""
    property string _secret: ""

    readonly property var _reasons: ({
        "2": "rejected",
        "3": "password",
        "4": "notFound",
        "5": "timeout",
        "6": "security"
    })

    function start(op: string, ssid: string, extra: string) {
        if (joinProc.running || !ssid.length)
            return;
        root._op = op;
        root._ssid = ssid;
        const cmd = [Paths.script("wifi-join.sh"), op, ssid];
        root._secret = op === "connect" && extra ? extra : "";
        if (root._secret.length > 0)
            cmd.push("-");
        joinProc.stdinEnabled = root._secret.length > 0;
        joinProc.command = cmd;
        joinProc.running = true;
    }

    function wake(ssid: string) {
        const cmd = [Paths.script("wifi-join.sh"), "wake"];
        if (ssid && ssid.length > 0)
            cmd.push(ssid);
        wakeProc.command = cmd;
        wakeProc.running = false;
        Qt.callLater(() => {
            wakeProc.running = true;
        });
    }

    Process {
        id: joinProc
        running: false
        onStarted: {
            if (root._secret.length > 0) {
                joinProc.write(root._secret + "\n");
                joinProc.stdinEnabled = false;
            }
            root._secret = "";
        }
        onExited: (code) => {
            const op = root._op;
            const ssid = root._ssid;
            root._op = "";
            root._secret = "";
            const reason = code === 0 ? "" : (root._reasons[String(code)] || "failed");
            if (code !== 0)
                Logger.warn("NetworkJoin", op + " failed: " + reason);
            root.finished(op, ssid, code === 0, reason);
        }
    }

    Process {
        id: wakeProc
        running: false
    }
}
