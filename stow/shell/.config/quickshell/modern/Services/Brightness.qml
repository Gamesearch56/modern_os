// Display brightness. Fetch/set: scripts/brightness.sh (backlight
// class or ddcutil VCP 10 — never LED devices).
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property bool watching: false
    property int percent: 100
    property bool available: false
    property string backend: ""
    property int display: 0
    property int _pending: -1
    property bool _fromUser: false

    readonly property string home: Quickshell.env("HOME")
    readonly property string script: root.home + "/modern_dotfile/scripts/brightness.sh"

    IpcHandler {
        target: "brightness"
        function up() { root.adjust(5); }
        function down() { root.adjust(-5); }
    }

    Process {
        id: getProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parse(this.text)
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim();
                if (t.length > 0)
                    Logger.warn("Brightness", t);
            }
        }
    }

    Process {
        id: setProc
        running: false
        stderr: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim();
                if (t.length === 0)
                    return;
                if (root._fromUser)
                    Logger.error("Brightness", t);
                else
                    Logger.warn("Brightness", t);
            }
        }
        onExited: (code) => {
            root._fromUser = false;
            if (code !== 0 && root.watching)
                Logger.error("Brightness", I18n.t("quickSettings.brightnessFailed"));
        }
    }

    Timer {
        interval: Motion.extraLongMs * 8
        running: root.watching && root.available
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        id: writeDebounce
        interval: Motion.shortMs * 2
        onTriggered: root._flush()
    }

    Component.onCompleted: root.refresh()

    function refresh() {
        getProc.running = false;
        getProc.command = [root.script, "get"];
        getProc.running = true;
    }

    function setPercent(value: int) {
        const v = Math.max(1, Math.min(100, Math.round(value)));
        root.percent = v;
        root._pending = v;
        root._fromUser = true;
        writeDebounce.restart();
    }

    function adjust(delta: int) {
        root.setPercent(root.percent + delta);
    }

    function _flush() {
        if (root._pending < 0)
            return;
        if (root.backend === "none" || root.backend.length === 0)
            return;
        setProc.running = false;
        setProc.command = [root.script, "set", String(root._pending)];
        setProc.running = true;
        root._pending = -1;
    }

    function _parse(text: string) {
        try {
            const j = JSON.parse(text);
            const ok = j?.available === true;
            const n = Number(j?.percent ?? 100);
            root.backend = String(j?.backend || "none");
            root.display = Number(j?.display ?? 0);
            root.available = ok && root.backend !== "none";
            if (typeof n === "number" && !isNaN(n) && root._pending < 0)
                root.percent = Math.max(1, Math.min(100, Math.round(n)));
        } catch (e) {
            root.available = false;
            root.backend = "none";
            Logger.warn("Brightness", "parse failed: " + e);
        }
    }
}
