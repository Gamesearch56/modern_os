// Glass card shared by the control panel and bar menus. Wash only —
// labels stay opaque (same split as MWindowShell / BarPopup).
import QtQuick
import "../Commons"

Rectangle {
    id: root

    color: "transparent"
    radius: Tokens.radius.medium
    border.color: Colors.color.outlineVariant
    border.width: Tokens.stroke.hairline
    clip: true

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Colors.color.surface
        opacity: Config.design.transparency ?? 0.85
        z: -1
    }
}
