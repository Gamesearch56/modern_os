// Separate Quickshell package for greetd. Cannot import the desktop
// shell's Commons/Widgets — those live in a different stow package
// and the greeter user has no $HOME view of them. Colors come from the
// shared session dir (docs/DECISIONS.md #14).
import Quickshell
import QtQuick

ShellRoot {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
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
