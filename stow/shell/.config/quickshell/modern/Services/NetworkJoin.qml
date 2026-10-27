// nmcli activate, forget, and disconnect. Quickshell's connectWithPsk
// can store a secret without bringing the network up.
import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Item {
    id: root

    readonly property bool running: joinProc.running
    readonly property bool waking: wakeProc.running
    signal finished(string op, string ssid, bool ok)

    property string _op: ""
    property string _ssid: ""

    function start(op: string, ssid: string, extra: string) {
        if (joinProc.running || !ssid.length)
            return;
        root._op = op;
        root._ssid = ssid;
        const cmd = [Paths.script("wifi-join.sh"), op, ssid];
        if (extra && extra.length > 0)
            cmd.push(extra);
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
        onExited: (code) => {
            const op = root._op;
            const ssid = root._ssid;
            root._op = "";
            root.finished(op, ssid, code === 0);
        }
    }

    Process {
        id: wakeProc
        running: false
    }
}
