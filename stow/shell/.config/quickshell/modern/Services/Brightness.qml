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
    property bool listReady: false
    property string lastError: ""
    property bool _ignoreGet: false
    property bool _ignoreList: false

    // UI blocks only while applying a user write — list/get must not freeze sliders.
    readonly property bool setting: setProc.running || writeDebounce.running || root._pending >= 0
    readonly property bool busy: root.setting
    readonly property string script: Paths.script("brightness.sh")

    BrightnessMatch { id: match }
    BrightnessWatch {
        id: watch
        getProc: getProc
        listProc: listProc
        setProc: setProc
        onGetTimedOut: root._abortGet()
        onListTimedOut: root._abortList()
        onSetTimedOut: root._abortSet()
    }

    IpcHandler {
        target: "brightness"
        function up() { root.adjust(5); }
        function down() { root.adjust(-5); }
    }

    Process {
        id: getProc
        running: false
        onRunningChanged: watch.armGet(running)
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root._ignoreGet)
                    root._parse(this.text);
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim();
                if (t.length > 0)
                    Logger.warn("Brightness", t);
            }
        }
        onExited: (code) => {
            if (root._ignoreGet) {
                root._ignoreGet = false;
                return;
            }
            if (code !== 0 && code !== 15 && !root.available)
                root.available = false;
        }
    }

    Process {
        id: listProc
        running: false
        onRunningChanged: watch.armList(running)
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root._ignoreList)
                    root._parseList(this.text);
            }
        }
        onExited: (code) => {
            root.listReady = true;
            if (root._ignoreList) {
                root._ignoreList = false;
                return;
            }
            if (code !== 0 && code !== 15 && (root.displays || []).length === 0)
                Logger.warn("Brightness", "list exited " + code);
        }
    }

    Process {
        id: setProc
        running: false
        onRunningChanged: watch.armSet(running)
        stderr: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim();
                if (t.length === 0)
                    return;
                root.lastError = t;
                if (root._fromUser)
                    Logger.error("Brightness", t);
                else
                    Logger.warn("Brightness", t);
            }
        }
        onExited: (code) => {
            root._fromUser = false;
            if (code !== 0 && code !== 15) {
                root.lastError = root.lastError || I18n.t("quickSettings.brightnessFailed");
                root._markPendingBroken();
                if (root.watching)
                    Logger.error("Brightness", I18n.t("quickSettings.brightnessFailed"));
            } else if (code === 0) {
                root.lastError = "";
            }
            root._pendingDesc = "";
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

    Component.onCompleted: {
        root.refresh();
        root.refreshDisplays();
    }

    function _abortGet() {
        if (!getProc.running)
            return;
        root._ignoreGet = true;
        getProc.running = false;
        Logger.warn("Brightness", "get timed out");
    }

    function _abortList() {
        if (!listProc.running)
            return;
        root._ignoreList = true;
        listProc.running = false;
        root.listReady = true;
        Logger.warn("Brightness", "list timed out");
    }

    function _abortSet() {
        if (!setProc.running)
            return;
        setProc.running = false;
        root._fromUser = false;
        root.lastError = I18n.t("quickSettings.brightnessFailed");
        root._markPendingBroken();
        root._pendingDesc = "";
        Logger.warn("Brightness", "set timed out");
    }

    function _markPendingBroken() {
        const d = root._pendingDesc.length ? root.matchFor(root._pendingDesc) : null;
        if (!d)
            return;
        d.ok = false;
        root.displays = root.displays.slice();
    }

    function refresh() {
        root._ignoreGet = false;
        getProc.running = false;
        getProc.command = [root.script, "get"];
        getProc.running = true;
    }

    function refreshDisplays() {
        root._ignoreList = false;
        listProc.running = false;
        listProc.command = [root.script, "list"];
        Qt.callLater(() => { listProc.running = true; });
    }

    function matchFor(description: string): var {
        return match.matchFor(root.displays, description);
    }
    function canControl(description: string): bool {
        return match.canControl(root.displays, description);
    }
    function canAdjust(description: string): bool {
        return match.canAdjust(root.displays, description);
    }
    function percentFor(description: string): int {
        return match.percentFor(root.displays, description, root.percent);
    }

    function setPercent(value: int) {
        if (!root.available)
            return;
        const v = Math.max(1, Math.min(100, Math.round(value)));
        root.percent = v;
        root._pending = v;
        root._pendingDesc = "";
        root._fromUser = true;
        root.lastError = "";
        writeDebounce.restart();
    }

    function setFor(description: string, value: int) {
        const v = Math.max(1, Math.min(100, Math.round(value)));
        const d = root.matchFor(description);
        if (!d || d.ok === false)
            return;
        d.percent = v;
        root.displays = root.displays.slice();
        if (String(d.backend) === "brightnessctl")
            root.percent = v;
        root._pending = v;
        root._pendingDesc = String(description || "");
        root._fromUser = true;
        root.lastError = "";
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
        const d = desc.length ? root.matchFor(desc) : null;
        setProc.running = false;
        if (d && String(d.backend) === "ddcutil")
            setProc.command = [root.script, "set", String(v), String(d.id)];
        else
            setProc.command = [root.script, "set", String(v)];
        setProc.running = true;
        if (!desc.length)
            root._pendingDesc = "";
    }

    function _parseList(text: string) {
        root.listReady = true;
        const next = match.parseList(text);
        if (next === null) {
            Logger.warn("Brightness", "list parse failed");
            return;
        }
        root.displays = next;
        if (match.anyOk(next))
            root.available = true;
    }

    function _parse(text: string) {
        const j = match.parseGet(text);
        if (!j) {
            if (String(text || "").trim().length > 0)
                Logger.warn("Brightness", "parse failed");
            return;
        }
        const ok = j?.available === true;
        const n = Number(j?.percent ?? 100);
        root.backend = String(j?.backend || "none");
        root.display = Number(j?.display ?? 0);
        root.available = ok && root.backend !== "none";
        if (typeof n === "number" && !isNaN(n) && root._pending < 0)
            root.percent = Math.max(1, Math.min(100, Math.round(n)));
    }
}
