import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../Services"

Scope {
    // ext_session_lock_v1: one WlSessionLockSurface per output. Shared
    // password lives on Session — never HyprlandFocusGrab / Exclusive
    // layer grabs (those fought across monitors and rebuilt the form).
    WlSessionLock {
        locked: Session.locked

        WlSessionLockSurface {
            color: "transparent"

            SessionSurface {
                anchors.fill: parent
            }
        }
    }
}
