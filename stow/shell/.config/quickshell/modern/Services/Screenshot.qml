// Owns grim capture and the region HUD open-state. Hyprland PRINT
// binds and the control-center Capture tile both call here.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property bool hudOpen: false
    property string mode: "region"
    property string _lastPath: ""
    property bool _exited: false
    property bool _outDone: false
    property bool _done: false
    property int _code: 0

    readonly property string home: Quickshell.env("HOME")
    readonly property string script: root.home + "/modern_dotfile/scripts/screenshot.sh"

    signal captured(string path)

    IpcHandler {
        target: "screenshot"
        function region() { root.pick("region"); }
        function window() { root.capture("window"); }
        function full() { root.capture("full"); }
        function pick() { root.pick("region"); }
    }

    Process {
        id: cap
        stdout: StdioCollector {
            id: capOut
            onStreamFinished: {
                root._lastPath = this.text.trim();
                root._outDone = true;
                root._tryFinish();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim();
                if (t.length > 0)
                    Logger.warn("Screenshot", t);
            }
        }
        onExited: (code) => {
            root._code = code;
            root._exited = true;
            Qt.callLater(root._tryFinish);
            finishGrace.restart();
        }
    }

    property string _pendingGeom: ""
    property string _pendingOutput: ""

    Timer {
        id: finishGrace
        interval: Motion.shortMs
        onTriggered: {
            if (!root._done && root._exited) {
                root._outDone = true;
                root._tryFinish();
            }
        }
    }

    Timer {
        id: hudGone
        interval: Motion.shortMs
        onTriggered: root._runRegion()
    }

    function _resetCap() {
        finishGrace.stop();
        root._done = false;
        root._exited = false;
        root._outDone = false;
        root._lastPath = "";
        cap.running = false;
    }

    function _tryFinish() {
        if (root._done || !root._exited)
            return;
        const path = (root._lastPath || capOut.text.trim());
        if (root._code === 0 && path.length === 0 && !root._outDone)
            return;
        root._done = true;
        finishGrace.stop();
        if (root._code === 0 && path.length > 0) {
            root.captured(path);
            return;
        }
        if (root._code !== 0)
            Logger.error("Screenshot", I18n.t("screenshot.failed"));
    }

    function pick(which: string) {
        const m = which || "region";
        root.mode = m;
        if (m === "region")
            root.hudOpen = true;
        else
            root.capture(m);
    }

    function capture(which: string) {
        root.hudOpen = false;
        root._resetCap();
        cap.command = [root.script, which || "region"];
        cap.running = true;
    }

    function finishRegion(geom: string, output: string) {
        root.hudOpen = false;
        if (!geom || geom.length === 0)
            return;
        root._pendingGeom = geom;
        root._pendingOutput = output || "";
        hudGone.restart();
    }

    function _runRegion() {
        const geom = root._pendingGeom;
        const output = root._pendingOutput;
        root._pendingGeom = "";
        root._pendingOutput = "";
        if (!geom || geom.length === 0)
            return;
        root._resetCap();
        if (output.length > 0)
            cap.command = [root.script, "region", geom, output];
        else
            cap.command = [root.script, "region", geom];
        cap.running = true;
    }

    function cancelHud() {
        root.hudOpen = false;
    }
}
