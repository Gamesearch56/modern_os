// Per-monitor bar. Layout is the three id-arrays in config.json
// (bar.left / center / right) — adding a widget is dropping a directory
// plus an id, never editing a switch here.
import Quickshell
import QtQuick

Scope {
    Variants {
        model: Quickshell.screens

        BarWindow {
            required property var modelData
            screen: modelData
        }
    }
}
