// Native folder chooser (kdialog, then zenity). Modules never spawn
// those processes or write the picked path — Settings does ConfigWrite.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string script: Paths.script("pick-directory.sh")

    signal directoryPicked(string path, string key)
    signal pickFinished(string section)

    property string _restoreSection: ""
    property string _configKey: ""

    Timer {
        id: startPick
        interval: Motion.shortMs
        repeat: false
        onTriggered: pick.running = true
    }

    Process {
        id: pick
        running: false
        stdout: StdioCollector {
            id: pickOut
        }
        stderr: StdioCollector {
            id: pickErr
        }
        onExited: (code) => {
            if (code === 0) {
                const path = pickOut.text.trim().split("\n").filter(l => l.length > 0).pop() || "";
                if (path.length)
                    root.directoryPicked(path, root._configKey);
            } else if (code !== 1) {
                const err = pickErr.text.trim();
                Logger.error("FilePick", err.length ? err : I18n.t("folderPicker.needChooser"));
            }
            const section = root._restoreSection;
            root._restoreSection = "";
            root._configKey = "";
            if (section.length)
                root.pickFinished(section);
        }
    }

    function pickDirectory(startPath: string, restoreSection: string, configKey: string) {
        try {
            root._restoreSection = restoreSection || "";
            root._configKey = configKey || "";
            pick.running = false;
            pick.command = [root.script, root._expand(startPath)];
            startPick.restart();
        } catch (e) {
            Logger.error("FilePick", String(e));
            const section = root._restoreSection;
            root._restoreSection = "";
            root._configKey = "";
            if (section.length)
                root.pickFinished(section);
        }
    }

    function _expand(p: string): string {
        let t = String(p || "").trim();
        if (t === "~" || t.indexOf("~/") === 0)
            t = root.home + t.slice(1);
        if (t.indexOf("file://") === 0) {
            t = t.slice(7);
            try {
                t = decodeURIComponent(t);
            } catch (e) {
            }
        }
        return t;
    }
}
