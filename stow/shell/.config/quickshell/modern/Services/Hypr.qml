// Hyprland IPC singleton. The only place the shell talks to Hyprland —
// workspaces, clients, monitors, dispatch. Modules never call hyprctl.
pragma Singleton

import Quickshell
import Quickshell.Hyprland
import QtQuick
import "../Commons"

Singleton {
    id: root

    readonly property var monitors: Hyprland.monitors
    readonly property var workspaces: Hyprland.workspaces
    readonly property var toplevels: Hyprland.toplevels
    readonly property var focusedWorkspace: Hyprland.focusedWorkspace
    readonly property var focusedToplevel: Hyprland.focusedToplevel

    function dispatch(cmd: string) {
        try {
            Hyprland.dispatch(cmd);
        } catch (e) {
            Logger.error("Hypr", "dispatch '" + cmd + "' failed: " + e);
        }
    }

    function focusWorkspace(id: int) {
        root.dispatch("workspace " + id);
    }

    function moveToWorkspace(id: int) {
        root.dispatch("movetoworkspace " + id);
    }

    function focusWindow(address: string) {
        root.dispatch("focuswindow address:" + address);
    }

    function closeWindow(address: string) {
        root.dispatch("closewindow address:" + address);
    }

    function reload() {
        root.dispatch("reload");
    }
}
