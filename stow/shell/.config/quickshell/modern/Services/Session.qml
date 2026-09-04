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

    IpcHandler {
        target: "session"
        function lock() { root.lock(); }
        function unlock() { root.unlock(); }
    }

    function lock() {
        try {
            // Do not call loginctl lock-session here. hypridle lock_cmd
            // is this IPC; lock-session would enqueue another lock and
            // put the overlay back after unlock.
            if (root.locked && root.mode === "lock")
                return;
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
        root.locked = false;
        root.mode = "lock";
        root.pendingAction = "";
        root.lastError = "";
        root.password = "";
        Quickshell.execDetached(["loginctl", "unlock-session"]);
    }

    function authenticate(password: string) {
        // Quickshell.Services.Pam.PamContext (`import Quickshell.Services.Pam`)
        // is the real verifier. Importing it unconditionally would fail the
        // whole shell on hosts where the session PAM stack isn't wired yet,
        // so M1 accepts a non-empty password and unlocks the overlay.
        // Replace this body with pam.start()/respond() once the gated
        // greetd phase lands (docs/ISOLATION.md).
        if (!password || password.length === 0) {
            root.lastError = "empty";
            return;
        }
        root.lastError = "";
        root.unlock();
    }

    function shutdownOverlay(action: string) {
        root.pendingAction = action;
        root.mode = "shutdown";
        root.locked = true;
    }
}
