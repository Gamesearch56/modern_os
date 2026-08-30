// Lock / greeter / shutdown overlay state. The only place PAM and
// loginctl lock are invoked — Modules/Session paints SessionSurface
// from `locked`/`mode` and never talks to the compositor lock protocol
// or PAM itself. WlSessionLock is the intended backend (docs/DECISIONS.md
// #7); M1 gates the overlay on `locked` so the UI is testable without
// a verified ext_session_lock_v1 round-trip.
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

    IpcHandler {
        target: "session"
        function lock() { root.lock(); }
        function unlock() { root.unlock(); }
    }

    function lock() {
        try {
            root.mode = "lock";
            root.pendingAction = "";
            root.locked = true;
            Quickshell.execDetached(["loginctl", "lock-session"]);
            Logger.info("Session", "lock requested");
        } catch (e) {
            Logger.error("Session", String(e));
        }
    }

    function unlock() {
        root.locked = false;
        root.mode = "lock";
        root.pendingAction = "";
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
