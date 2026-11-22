// Owns wf-recorder via screencast.sh. Writes only videoDirectory.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property bool active: false
    property string _path: ""
    property bool _stopping: false

    readonly property string home: Quickshell.env("HOME")
    readonly property string script: Paths.script("screencast.sh")

    signal saved(string path)
    signal failed()

    IpcHandler {
        target: "recording"
        function startRegion() { root.start("region", "", ""); }
        function window() { root.start("window", "", ""); }
        function full() { root.start("full", "", ""); }
        function stop() { root.stop(); }
    }

    Process {
        id: rec
        stdout: StdioCollector {
            id: recOut
            onStreamFinished: {
                const t = this.text.trim().split("\n")[0] || "";
                if (t.length > 0)
                    root._path = t;
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim();
                if (t.length > 0)
                    Logger.warn("Recording", t);
            }
        }
        onExited: (code) => {
            const stopping = root._stopping;
            root.active = false;
            root._stopping = false;
            const path = root._path || recOut.text.trim().split("\n")[0] || "";
            root._path = "";
            if (code === 0 && path.length > 0) {
                root.saved(path);
                return;
            }
            if (stopping)
                return;
            root.failed();
        }
    }

    Process {
        id: stopper
        // A stop that did not end the recorder must be tryable again.
        // Leaving _stopping set made the button and the shortcut no-ops.
        onExited: {
            if (root.active)
                root._stopping = false;
        }
    }

    Timer {
        id: hudGone
        interval: Motion.shortMs
        property string mode: "region"
        property string geom: ""
        property string output: ""
        onTriggered: root._run(hudGone.mode, hudGone.geom, hudGone.output)
    }

    function start(mode: string, geom: string, output: string) {
        if (root.active)
            return;
        hudGone.mode = mode || "region";
        hudGone.geom = geom || "";
        hudGone.output = output || "";
        hudGone.restart();
    }

    function _run(mode: string, geom: string, output: string) {
        rec.running = false;
        root._path = "";
        if (geom.length > 0 && output.length > 0)
            rec.command = [root.script, mode, geom, output];
        else if (geom.length > 0)
            rec.command = [root.script, mode, geom];
        else
            rec.command = [root.script, mode];
        rec.running = true;
        root.active = true;
    }

    function stop() {
        if (!root.active || root._stopping)
            return;
        root._stopping = true;
        stopper.running = false;
        stopper.command = [root.script, "stop"];
        stopper.running = true;
    }
}
