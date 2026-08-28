// Freedesktop icon by name, sized from Tokens. Widgets never pick a
// color by hex — `color` tints the pixmap when the theme icon is
// symbolic. Prefer `name` over a raw URL so icon-theme switches apply.
import QtQuick
import Quickshell
import Quickshell.Widgets
import "../Commons"

Item {
    id: root

    property string name: ""
    property int size: Tokens.spacing.lg
    property color color: Colors.color.onSurface

    implicitWidth: root.size
    implicitHeight: root.size

    IconImage {
        anchors.fill: parent
        source: root.name.length > 0 ? Quickshell.iconPath(root.name) : ""
        mipmap: true
        asynchronous: true
    }
}
