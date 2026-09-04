// Writes hypridle.conf from general.idleTimings and restarts hypridle.
// Settings only writes config.json; this Service owns the idle daemon file.
pragma Singleton

import Quickshell
import QtQuick
import "../Commons"

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string bright: Paths.script("brightness.sh")

    readonly property int dimSec: Config.general.idleTimings.dimSec ?? 120
    readonly property int offSec: Config.general.idleTimings.screenOffSec ?? 300
    readonly property int lockSec: Config.general.idleTimings.lockSec ?? 600
    readonly property int suspendSec: Config.general.idleTimings.suspendSec ?? 1800

    onDimSecChanged: applyWait.restart()
    onOffSecChanged: applyWait.restart()
    onLockSecChanged: applyWait.restart()
    onSuspendSecChanged: applyWait.restart()
    Component.onCompleted: applyWait.restart()

    Timer {
        id: applyWait
        interval: 300
        onTriggered: root._flush()
    }

    function _listener(timeout: int, onTimeout: string, onResume: string): string {
        let s = "listener {\n    timeout = " + timeout + "\n    on-timeout = " + onTimeout + "\n";
        if (onResume.length > 0)
            s += "    on-resume = " + onResume + "\n";
        return s + "}\n";
    }

    function _render(): string {
        const b = root.bright;
        return "general {\n"
            + "    lock_cmd = qs -c modern ipc call session lock\n"
            + "    before_sleep_cmd = qs -c modern ipc call session lock\n"
            + "    after_sleep_cmd = hyprctl dispatch dpms on\n"
            + "    ignore_dbus_inhibit = false\n"
            + "}\n"
            + root._listener(root.dimSec, b + " dim", b + " undim")
            + root._listener(root.offSec, "hyprctl dispatch dpms off", "hyprctl dispatch dpms on")
            + root._listener(root.lockSec, "qs -c modern ipc call session lock", "")
            + root._listener(root.suspendSec, "systemctl suspend", "");
    }

    function _flush() {
        const body = root._render();
        // Restart only when the file actually changes. A login-time
        // pkill of every hypridle races the compositor and can lock
        // the new session as soon as the bar appears.
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p \"$HOME/.config/hypr\"; "
            + "conf=\"$HOME/.config/hypr/hypridle.conf\"; "
            + "tmp=$(mktemp); cat > \"$tmp\" <<'MODERN_HYPRIDLE'\n"
            + body
            + "\nMODERN_HYPRIDLE\n"
            + "if [ -f \"$conf\" ] && cmp -s \"$tmp\" \"$conf\"; then "
            + "rm -f \"$tmp\"; pgrep -x hypridle >/dev/null || hypridle &; exit 0; fi; "
            + "mv -f \"$tmp\" \"$conf\"; "
            + "pkill -x hypridle 2>/dev/null || true; hypridle &"]);
    }
}
