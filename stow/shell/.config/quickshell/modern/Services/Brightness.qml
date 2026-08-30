// Display brightness via scripts/brightness.sh (backlight or ddcutil VCP 10).
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
    property var displays: []
    property int _pending: -1
    property string _pendingDesc: ""
    property bool _fromUser: false

    readonly property string script: Paths.script("brightness.sh")

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
        id: listProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parseList(this.text)
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

    function refreshDisplays() {
        listProc.running = false;
        listProc.command = [root.script, "list"];
        Qt.callLater(() => {
            listProc.running = true;
        });
    }

    function matchFor(description: string): var {
        const desc = String(description || "").toLowerCase();
        const list = root.displays || [];
        let backlight = null;
        for (let i = 0; i < list.length; i++) {
            const d = list[i];
            if (!d)
                continue;
            if (String(d.backend) === "brightnessctl") {
                backlight = d;
                continue;
            }
            const serial = String(d.serial || "").toLowerCase();
            const model = String(d.model || "").toLowerCase();
            if (serial.length > 0 && desc.indexOf(serial) !== -1)
                return d;
            if (model.length > 0 && desc.indexOf(model) !== -1)
                return d;
        }
        return backlight;
    }

    function canControl(description: string): bool {
        return root.matchFor(description) !== null;
    }

    function percentFor(description: string): int {
        const d = root.matchFor(description);
        if (d && typeof d.percent === "number")
            return d.percent;
        return root.percent;
    }

    function setPercent(value: int) {
        const v = Math.max(1, Math.min(100, Math.round(value)));
        root.percent = v;
        root._pending = v;
        root._pendingDesc = "";
        root._fromUser = true;
        writeDebounce.restart();
    }

    function setFor(description: string, value: int) {
        const v = Math.max(1, Math.min(100, Math.round(value)));
        const d = root.matchFor(description);
        if (!d)
            return;
        d.percent = v;
        root.displays = root.displays.slice();
        if (String(d.backend) === "brightnessctl")
            root.percent = v;
        root._pending = v;
        root._pendingDesc = String(description || "");
        root._fromUser = true;
        writeDebounce.restart();
    }

    function adjust(delta: int) {
        root.setPercent(root.percent + delta);
    }

    function _flush() {
        if (root._pending < 0)
            return;
        const v = root._pending;
        const desc = root._pendingDesc;
        root._pending = -1;
        root._pendingDesc = "";
        const d = desc.length ? root.matchFor(desc) : null;
        setProc.running = false;
        if (d && String(d.backend) === "ddcutil")
            setProc.command = [root.script, "set", String(v), String(d.id)];
        else
            setProc.command = [root.script, "set", String(v)];
        setProc.running = true;
    }

    function _parseList(text: string) {
        try {
            const j = JSON.parse(text);
            root.displays = j?.displays || [];
        } catch (e) {
            root.displays = [];
            Logger.warn("Brightness", "list parse failed: " + e);
        }
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
