// Applies hypridle.conf from config.json whenever Config reloads.
// Nested idleTimings ints do not always notify; generation does.
pragma Singleton

import Quickshell
import QtQuick
import "../Commons"

Singleton {
    id: root

    readonly property int configGen: Config.generation

    onConfigGenChanged: applyWait.restart()
    Component.onCompleted: applyWait.restart()

    Timer {
        id: applyWait
        interval: 300
        onTriggered: Quickshell.execDetached([Paths.script("hypridle-apply.sh")])
    }
}
