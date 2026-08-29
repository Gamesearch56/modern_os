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
            onStreamFinished: root._lastPath = this.text.trim()
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim();
                if (t.length > 0)
                    Logger.warn("Screenshot", t);
            }
        }
        onExited: (code) => {
            if (code === 0 && root._lastPath.length > 0) {
                root.captured(root._lastPath);
                return;
            }
            if (code !== 0)
                Logger.error("Screenshot", I18n.t("screenshot.failed"));
        }
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
        cap.running = false;
        cap.command = [root.script, which || "region"];
        cap.running = true;
    }

    function finishRegion(geom: string, output: string) {
        root.hudOpen = false;
        if (!geom || geom.length === 0)
            return;
        cap.running = false;
        if (output && output.length > 0)
            cap.command = [root.script, "region", geom, output];
        else
            cap.command = [root.script, "region", geom];
        cap.running = true;
    }

    function cancelHud() {
        root.hudOpen = false;
    }
}
