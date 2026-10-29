// Lock / greeter / shutdown overlay state. `locked` drives
// WlSessionLock (ext_session_lock_v1) in Modules/Session. `password`
// is shared across every lock surface so typing stays in sync.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property bool locked: false
    property string mode: "lock"
    property string pendingAction: ""
    property string lastError: ""
    property string password: ""
    readonly property bool busy: auth.busy

    IpcHandler {
        target: "session"
        function lock() { root.lock(); }
        function unlock() { root.unlock(); }
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

    function shutdownOverlay(action: string) {
        root.pendingAction = action;
        root.mode = "shutdown";
        root.locked = true;
    }
}
