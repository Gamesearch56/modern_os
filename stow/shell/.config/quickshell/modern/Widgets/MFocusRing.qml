// Primary outline after keyboard travel. Pointer clicks and
// programmatic focus (dialog open, page load) stay unringed until
// MFocusWalk.move() calls markKeyboard(). Shortcut menus bind `active`
// to a currentIndex instead of parent.activeFocus.
import QtQuick
import "../Commons"

Rectangle {
    id: root

    property bool keyboardOnly: true
    property bool _pointer: false
    property bool _shown: false
    property bool active: parent && parent.activeFocus && root._shown
        && !(root.keyboardOnly && root._pointer)
    property color ringColor: Colors.color.primary

    function markPointer() {
        root._pointer = true;
        root._shown = false;
    }

    function markKeyboard() {
        root._pointer = false;
        root._shown = true;
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
            if (!root.parent || !root.parent.activeFocus) {
                root._pointer = false;
                root._shown = false;
            }
        }
    }
}
