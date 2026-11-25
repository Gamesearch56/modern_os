// First-run detector. FileView on config.json — missing file means the
// onboarding wizard should run. complete() copies the shipped default
// so the wizard does not loop. ConfigWrite exists for Settings writes;
// this path still copies default.json so a missing live file is seeded
// without going through the CLI. Onboarding also opens Settings afterwards.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string configPath: `${root.home}/.config/modern/config.json`
    readonly property string defaultPath: `${root.home}/.config/modern/config.default.json`

    property bool configPresent: false
    readonly property bool isFirstRun: !root.configPresent

    FileView {
        id: live
        path: root.configPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.configPresent = true
        onLoadFailed: root.configPresent = false
    }

    FileView {
        id: bundled
        path: root.defaultPath
        printErrors: false
    }

    function complete() {
        try {
            const text = bundled.text();
            if (text && text.length > 0)
                live.setText(text);
            else {
                Logger.error("FirstRun", "config.default.json is empty or unreadable");
                return;
            }
        } catch (e) {
            Logger.warn("FirstRun", "FileView setText failed, copying with cp: " + e);
            Quickshell.execDetached(["cp", "-n", root.defaultPath, root.configPath]);
        }
        root.configPresent = true;
    }
}
