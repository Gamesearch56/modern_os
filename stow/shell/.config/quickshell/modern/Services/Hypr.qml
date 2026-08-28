// Hyprland IPC singleton. The only place the shell talks to Hyprland —
// workspaces, clients, monitors, dispatch. Modules never call hyprctl.
pragma Singleton

import Quickshell
import Quickshell.Hyprland
import QtQuick

Singleton {
    id: root

    readonly property var monitors: Hyprland.monitors
    readonly property var workspaces: Hyprland.workspaces
    readonly property var toplevels: Hyprland.toplevels
    readonly property var focusedWorkspace: Hyprland.focusedWorkspace
    readonly property var focusedToplevel: Hyprland.focusedToplevel

    function dispatch(cmd: string) {
        Hyprland.dispatch(cmd);
    }

    function focusWorkspace(id: int) {
        Hyprland.dispatch("workspace " + id);
    }

    function moveToWorkspace(id: int) {
        Hyprland.dispatch("movetoworkspace " + id);
    }

    function focusWindow(address: string) {
        Hyprland.dispatch("focuswindow address:" + address);
    }

    function closeWindow(address: string) {
        Hyprland.dispatch("closewindow address:" + address);
    }

    function reload() {
        Hyprland.dispatch("reload");
    }
}
