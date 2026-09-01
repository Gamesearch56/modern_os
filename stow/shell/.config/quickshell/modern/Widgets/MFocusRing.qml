// Primary outline for keyboard focus or a programmatic current item.
// Pointer clicks must not paint this ring — only Tab/arrows/shortcuts.
// Call markPointer() from the host's MouseArea; shortcut-driven menus
// bind `active` to a currentIndex instead of parent.activeFocus.
import QtQuick
import "../Commons"

Rectangle {
    id: root

    property bool keyboardOnly: true
    property bool _pointer: false
    property bool active: parent && parent.activeFocus && !(root.keyboardOnly && root._pointer)
    property color ringColor: Colors.color.primary

    function markPointer() {
        root._pointer = true;
    }

    anchors.fill: parent
    color: "transparent"
    border.color: root.ringColor
    border.width: root.active ? Tokens.stroke.focus : 0
    visible: root.active
    enabled: false
    z: 20

    Connections {
        target: root.parent
        function onActiveFocusChanged() {
            if (!root.parent || !root.parent.activeFocus)
                root._pointer = false;
        }
    }
}
