// Primary outline for keyboard focus or a programmatic current item.
// Shortcut-driven menus never move Qt focus, so `active` can be bound
// to a currentIndex instead of relying on parent.activeFocus.
import QtQuick
import "../Commons"

Rectangle {
    id: root

    property bool active: parent && parent.activeFocus
    property color ringColor: Colors.color.primary

    anchors.fill: parent
    color: "transparent"
    border.color: root.ringColor
    border.width: root.active ? Tokens.stroke.focus : 0
    visible: root.active
    z: 20
}
