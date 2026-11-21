// Session power actions. The only place loginctl/systemctl are invoked
// — the power menu and lock screen call these methods, never exec.
pragma Singleton

import Quickshell
import QtQuick
import "../Commons"

Singleton {
    id: root

    function lock() {
        Quickshell.execDetached(["qs", "-c", "modern", "ipc", "call", "session", "lock"]);
    }

    function logout() {
        // Lua configs reject `dispatch exit` (Hyprland 0.55+). The helper
        // puts the splash up first so the seat terminal stays hidden.
        Quickshell.execDetached([Paths.script("splash-hold.sh"), "logout"]);
    }

    // `modern power` waits for the compositor to confirm the lock before
    // sleeping; locking and suspending side by side raced on wake.
    function suspend() {
        Quickshell.execDetached([Paths.script("modern"), "power", "suspend"]);
    }

    function hibernate() {
        Quickshell.execDetached([Paths.script("modern"), "power", "hibernate"]);
    }

    function reboot() {
        Quickshell.execDetached([Paths.script("splash-hold.sh"), "reboot"]);
    }

    function poweroff() {
        Quickshell.execDetached([Paths.script("splash-hold.sh"), "poweroff"]);
    }
}
