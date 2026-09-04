// Repo and XDG paths. Services use these instead of concatenating
// `$HOME/modern_dotfile/scripts` in every file.
pragma Singleton

import Quickshell
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
    readonly property string repo: root.home + "/modern_dotfile"
    readonly property string scripts: root.repo + "/scripts"
    readonly property string modern: root.scripts + "/modern"
    readonly property string modernLaunch: root.scripts + "/modern-launch"
    readonly property string brandLogo: root.configHome + "/modern/brand/logo.png"

    function script(name: string): string {
        return root.scripts + "/" + name;
    }
}
