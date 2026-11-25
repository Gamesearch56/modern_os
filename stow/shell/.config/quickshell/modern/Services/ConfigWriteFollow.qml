// Post-write jobs for ConfigWrite (hyprctl, session sync, chrome).
import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Item {
    id: root

    property var writer: null

    readonly property bool busy: followProc.running || chromeDebounce.running
        || ((root._q || []).length > 0)

    property var _q: []

    function enqueue(cmd) {
        const key = (cmd || []).join("\t");
        const q = root._q || [];
        for (let i = 0; i < q.length; i++) {
            if ((q[i] || []).join("\t") === key)
                return;
        }
        root._q = q.concat([cmd]);
        root.kick();
    }

    function requestChrome() {
        chromeDebounce.restart();
    }

    function kick() {
        const w = root.writer;
        if (!w || followProc.running || w.writing)
            return;
        const q = root._q || [];
        if (q.length === 0)
            return;
        followProc.command = q[0];
        root._q = q.slice(1);
        followProc.running = true;
    }

    function _abortHang() {
        if (!followProc.running)
            return;
        followProc.running = false;
        root._q = [];
        Logger.warn("ConfigWrite", "follow job timed out");
    }

    // ConfigWrite enqueues from the write's onExited, while `writing` is
    // still true, so kick() bails there; without this the queue (and the
    // Settings busy indicator) would wait for an unrelated later write.
    Connections {
        target: root.writer
        function onWritingChanged() {
            if (!root.writer.writing)
                root.kick();
        }
    }

    Timer {
        id: chromeDebounce
        interval: Math.max(Motion.mediumMs, 1)
        repeat: false
        onTriggered: root.enqueue([
            Paths.script("theme-apply.sh"),
            "--chrome-only"
        ])
    }

    Timer {
        id: followWatch
        interval: Motion.followWatchMs
        repeat: false
        onTriggered: root._abortHang()
    }

    Process {
        id: followProc
        onRunningChanged: {
            if (running)
                followWatch.restart();
            else
                followWatch.stop();
        }
        onExited: root.kick()
    }
}
