import Quickshell
import QtQuick

Scope {
    Variants {
        model: Quickshell.screens

        DockWindow {
            required property var modelData
            screen: modelData
        }
    }

    DockGhost {}
}
