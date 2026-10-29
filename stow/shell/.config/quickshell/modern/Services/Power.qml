// Session power actions. The only place loginctl/systemctl are invoked
// — the power menu and lock screen call these methods, never exec.
pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    function lock() {
        Quickshell.execDetached(["qs", "-c", "modern", "ipc", "call", "session", "lock"]);
    }

    function logout() {
        // Lua configs reject `dispatch exit` (Hyprland 0.55+).
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.exit()"]);
    }

    function suspend() {
        Quickshell.execDetached(["qs", "-c", "modern", "ipc", "call", "session", "lock"]);
        Quickshell.execDetached(["systemctl", "suspend"]);
    }

    function hibernate() {
        Quickshell.execDetached(["systemctl", "hibernate"]);
    }

    function reboot() {
        Quickshell.execDetached(["systemctl", "reboot"]);
    }

    function poweroff() {
        Quickshell.execDetached(["systemctl", "poweroff"]);
    }
}
