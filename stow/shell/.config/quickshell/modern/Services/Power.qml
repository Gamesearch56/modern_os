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
        // Lua configs reject `dispatch exit` (Hyprland 0.55+). The helper
        // puts the splash up first so the seat terminal stays hidden.
        Quickshell.execDetached(["/usr/lib/modern/splash-hold.sh", "logout"]);
    }

    function suspend() {
        Quickshell.execDetached(["qs", "-c", "modern", "ipc", "call", "session", "lock"]);
        Quickshell.execDetached(["systemctl", "suspend"]);
    }

    function hibernate() {
        Quickshell.execDetached(["systemctl", "hibernate"]);
    }

    function reboot() {
        Quickshell.execDetached(["/usr/lib/modern/splash-hold.sh", "reboot"]);
    }

    function poweroff() {
        Quickshell.execDetached(["/usr/lib/modern/splash-hold.sh", "poweroff"]);
    }
}
