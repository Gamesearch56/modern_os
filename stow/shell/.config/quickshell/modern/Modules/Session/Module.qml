import Quickshell
import QtQuick
import "../../Services"

Scope {
    LazyLoader {
        active: Session.locked

        PanelWindow {
            visible: Session.locked
            color: "transparent"
            anchors.top: true
            anchors.left: true
            anchors.right: true
            anchors.bottom: true
            exclusionMode: ExclusionMode.Ignore
            focusable: true

            SessionSurface {
                anchors.fill: parent
            }
        }
    }
}
