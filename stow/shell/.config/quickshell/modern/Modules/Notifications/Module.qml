import Quickshell
import QtQuick
import "../../Commons"
import "../../Services"

Scope {
    LazyLoader {
        active: !Notifications.panelOpen && Notifications.list.length > 0

        PanelWindow {
            visible: !Notifications.panelOpen && Notifications.list.length > 0
            color: "transparent"
            anchors.top: true
            anchors.right: true
            implicitWidth: Tokens.spacing.xxl * 12
            implicitHeight: Tokens.spacing.xxl * 16
            exclusionMode: ExclusionMode.Ignore
            margins.top: Tokens.spacing.xl
            margins.right: Tokens.spacing.xl

            Toasts {
                anchors.top: parent.top
                anchors.right: parent.right
            }
        }
    }

    LazyLoader {
        active: Notifications.panelOpen

        PanelWindow {
            visible: Notifications.panelOpen
            color: "transparent"
            anchors.top: true
            anchors.left: true
            anchors.right: true
            anchors.bottom: true
            exclusionMode: ExclusionMode.Ignore
            focusable: true

            Panel {
                anchors.fill: parent
            }

            Shortcut {
                sequence: "Escape"
                onActivated: Notifications.hide()
            }
        }
    }
}
