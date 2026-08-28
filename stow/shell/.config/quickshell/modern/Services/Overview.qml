// SUPER+Tab overview overlay state. IpcHandler lives here so Hyprland
// and `modern overview toggle` share one flag; the Module only renders.
pragma Singleton

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool open: false

    function toggle() { root.open = !root.open; }
    function show() { root.open = true; }
    function hide() { root.open = false; }

    IpcHandler {
        target: "overview"
        function toggle() { root.toggle(); }
        function show() { root.show(); }
        function hide() { root.hide(); }
    }
}
