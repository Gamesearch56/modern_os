// Circular icon-only button. Hover fades a primary state-layer.
import QtQuick
import "../Commons"

Item {
    id: root

    property string iconName: ""
    property url iconSource: ""
    property string key: ""
    property bool checked: false
    property bool enabled: true
    property int size: Tokens.spacing.xxl
    property int iconSize: Tokens.icon.md
    property bool close: false
    property bool tint: true

    signal clicked()
    signal middleClicked()
    signal rightClicked()
    signal wheel(real steps)

    implicitWidth: root.size
    implicitHeight: root.size
    opacity: root.enabled ? 1 : 0.38
    activeFocusOnTab: false
    Accessible.role: Accessible.Button
    Accessible.name: root.key.length > 0 ? I18n.t(root.key) : root.iconName
    Accessible.onPressAction: root.clicked()

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.clicked();
            event.accepted = true;
        }
    }

    property bool _hover: false
    property bool _suppressHover: false

    readonly property color _iconColor: {
        if (root.close)
            return Colors.color.error;
        if (root.checked)
            return Colors.color.onPrimaryContainer;
        return Colors.color.onSurface;
    }

    readonly property real _layer: Chrome.stateLayer(root._hover && !root.checked, ma.pressed && !root.checked)

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
        color: root.close ? Colors.color.error : Colors.color.primary
        visible: root._layer > 0
        opacity: root._layer
    }

    MIcon {
        anchors.centerIn: parent
        name: root.iconName
        source: root.iconSource
        size: root.iconSize
        color: root._iconColor
        tint: root.tint
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }
        onEntered: {
            if (!root._suppressHover)
                root._hover = true;
        }
        onExited: {
            if (root.checked)
                return;
            root._hover = false;
            root._suppressHover = false;
        }
        onContainsMouseChanged: {
            if (containsMouse) {
                root._hover = true;
                return;
            }
            if (root.checked)
                return;
            root._hover = false;
            root._suppressHover = false;
        }
        onClicked: (mouse) => {
            if (mouse.button === Qt.MiddleButton)
                root.middleClicked();
            else if (mouse.button === Qt.RightButton)
                root.rightClicked();
            else
                root.clicked();
            root._hover = true;
            root._suppressHover = false;
        }
        onWheel: (w) => root.wheel(w.angleDelta.y > 0 ? 1 : -1)
    }

    onCheckedChanged: {
        if (root.checked) {
            root._hover = true;
            root._suppressHover = false;
            return;
        }
        root._hover = false;
        root._suppressHover = true;
    }
}
