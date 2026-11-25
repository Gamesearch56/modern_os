// Lock / greeter / shutdown overlay state. `locked` drives
// WlSessionLock (ext_session_lock_v1) in Modules/Session. `password`
// is shared across every lock surface so typing stays in sync.
//
// A shell reload (updates run reload-ui.sh) or crash while locked would
// start the new shell unlocked, leaving Hyprland's lock without a live
// surface. A marker in XDG_RUNTIME_DIR (gone at logout/reboot) is read
// synchronously before WlSessionLock binds, so the new shell starts
// locked; Hyprland's misc:allow_session_lock_restore lets it take over.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    readonly property string _runtime: Quickshell.env("XDG_RUNTIME_DIR") || ""

    FileView {
        id: marker
        path: root._runtime.length ? `${root._runtime}/modern-session-locked` : ""
        blockLoading: true
        printErrors: false
    }

    property bool locked: marker.path.length > 0 && marker.text().trim() === "1"
    onLockedChanged: {
        if (marker.path.length)
            marker.setText(root.locked ? "1" : "");
        if (root.locked && !root.secure)
            confirmWatch.restart();
    }
    // True once the compositor confirms every output is covered. Suspend
    // waits on this (secured IPC); `locked` alone is only the request.
    property bool secure: false
    function reportSecure(value: bool) {
        root.secure = value;
        if (value) {
            confirmWatch.stop();
            Logger.info("Session", "lock confirmed by the compositor");
        }
    }

    Timer {
        id: confirmWatch
        interval: 3000
        onTriggered: {
            if (root.locked && !root.secure)
                Logger.error("Session", "compositor has not confirmed the lock after 3 s");
        }
    }
    property string mode: "lock"
    property string pendingAction: ""
    property string lastError: ""
    property string password: ""
    readonly property bool busy: auth.busy

    IpcHandler {
        target: "session"
        function lock() { root.lock(); }
        function unlock() { root.unlock(); }
        function secured(): bool { return root.locked && root.secure; }
    }

    SessionAuth {
        id: auth
        host: root
    }

    function lock() {
        try {
            // Do not call loginctl lock-session here. hypridle lock_cmd
            // is this IPC; lock-session would enqueue another lock and
            // put the overlay back after unlock.
            if (root.locked && root.mode === "lock")
                return;
            auth.abort();
            root.mode = "lock";
            root.pendingAction = "";
            root.lastError = "";
            root.password = "";
            root.locked = true;
            Logger.info("Session", "lock requested");
        } catch (e) {
            Logger.error("Session", String(e));
        }
    }

    function unlock() {
        Logger.info("Session", "unlocked");
        auth.abort();
        root.locked = false;
        root.mode = "lock";
        root.pendingAction = "";
        root.lastError = "";
        root.password = "";
        Quickshell.execDetached(["loginctl", "unlock-session"]);
    }

    function authenticate(password: string) {
        if (root.mode === "shutdown" || root.busy)
            return;
        auth.authenticate(password);
    }

}
