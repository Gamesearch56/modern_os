// Folder choice uses the file manager. Settings only stores the path.
pragma Singleton

import Quickshell
import QtQuick
import "../Commons"

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")

    signal directoryPicked(string path, string key)
    signal pickFinished(string section)

    property string _restoreSection: ""
    property string _configKey: ""

    function pickDirectory(startPath: string, restoreSection: string, configKey: string) {
        root._restoreSection = restoreSection || "";
        root._configKey = configKey || "";
        FilesChoose.ask(root._expand(startPath), "folder", "directory");
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

    function _finish(path: string) {
        const key = root._configKey;
        const section = root._restoreSection;
        root._configKey = "";
        root._restoreSection = "";
        if (path.length)
            root.directoryPicked(path, key);
        if (section.length)
            root.pickFinished(section);
    }

    Connections {
        target: FilesChoose
        function onChosen(path, who) {
            if (who === "directory")
                root._finish(String(path || ""));
        }
        function onCancelled(who) {
            if (who === "directory")
                root._finish("");
        }
    }
}
