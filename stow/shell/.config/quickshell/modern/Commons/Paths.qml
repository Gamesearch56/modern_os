// Repo and XDG paths. Services use these instead of concatenating
// `$HOME/modern_os/scripts` in every file.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string configHome: {
        const e = Quickshell.env("XDG_CONFIG_HOME");
        return (e && e.length > 0) ? e : (root.home + "/.config");
    }
    readonly property string stateHome: {
        const e = Quickshell.env("XDG_STATE_HOME");
        return (e && e.length > 0) ? e : (root.home + "/.local/state");
    }
    readonly property string runtimeHome: {
        const e = Quickshell.env("XDG_RUNTIME_DIR");
        return (e && e.length > 0) ? e : root.stateHome;
    }
    property string _fileRepo: ""
    readonly property string _envRepo: {
        const e = Quickshell.env("MODERN_REPO");
        return (e && e.length > 0) ? e : "";
    }
    readonly property string repo: {
        if (root._envRepo.length > 0)
            return root._envRepo;
        if (root._fileRepo.length > 0)
            return root._fileRepo;
        return root.home + "/modern_os";
    }
    readonly property string scripts: root.repo + "/scripts"
    readonly property string modern: root.scripts + "/modern"
    readonly property string modernLaunch: root.scripts + "/modern-launch"
    readonly property string brandLogo: root.configHome + "/modern/brand/logo.png"

    FileView {
        path: root.configHome + "/modern/repo"
        watchChanges: true
        printErrors: false
        onLoaded: {
            const t = String(text() || "").trim().split("\n")[0].trim();
            root._fileRepo = t;
        }
        onLoadFailed: root._fileRepo = ""
    }

    function script(name: string): string {
        return root.scripts + "/" + name;
    }
}
