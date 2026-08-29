// Full-pill hit target for single-widget islands. Chrome sits behind
// the widget's icon/label; the MouseArea is reparented on top so hover
// cannot paint over the glyphs.
import QtQuick
import "../../Commons"

Item {
    id: root

    property bool checked: false

    signal clicked(var mouse)
    signal middleClicked()
    signal rightClicked()
    signal wheel(real steps)
    signal entered()
    signal exited()

    anchors.fill: parent
    z: 0

    readonly property bool hovered: ma.containsMouse
    readonly property real _layer: Chrome.stateLayer(ma.containsMouse, ma.pressed)

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.full
        color: Chrome.tonal.bg
        visible: root.checked
    }

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.full
        color: "transparent"
        border.width: Tokens.stroke.focus
        border.color: Colors.color.primary
        visible: root.checked
    }

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.full
        color: Colors.color.primary
        visible: root._layer > 0
        opacity: root._layer
    }

    MouseArea {
        id: ma
        parent: root.parent
        anchors.fill: parent
        z: 2
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }
        onEntered: root.entered()
        onExited: root.exited()
        onClicked: (mouse) => {
            if (mouse.button === Qt.MiddleButton)
                root.middleClicked();
            else if (mouse.button === Qt.RightButton)
                root.rightClicked();
            else
                root.clicked(mouse);
        }
        onWheel: (w) => root.wheel(w.angleDelta.y > 0 ? 1 : -1)
    }
}
