// Sits above a shell surface while a program is opening. HoverHandler
// does not take clicks, so the button underneath still receives them,
// and the pointer is the watch instead of that button's arrow.
import QtQuick

Item {
    z: 1000
    enabled: LaunchCursor.busy
    visible: LaunchCursor.busy

    HoverHandler {
        cursorShape: Qt.BusyCursor
    }
}
