// Circular icon-only button. Hover fades a primary state-layer.
import QtQuick
import "../Commons"

Item {
    id: root

    property string iconName: ""
    property string key: ""
    property bool checked: false
    property bool enabled: true
    property int size: Tokens.spacing.xxl
    property int iconSize: Tokens.icon.md
    property bool close: false

    signal clicked()
    signal middleClicked()
    signal rightClicked()
    signal wheel(real steps)

    implicitWidth: root.size
    implicitHeight: root.size
    opacity: root.enabled ? 1 : 0.38
    activeFocusOnTab: root.enabled
    Accessible.role: Accessible.Button
    Accessible.name: root.key.length > 0 ? I18n.t(root.key) : root.iconName
    Accessible.onPressAction: root.clicked()

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.clicked();
            event.accepted = true;
        }
    }

    readonly property color _iconColor: {
        if (root.close)
            return Colors.color.error;
        if (root.checked)
            return Colors.color.onPrimaryContainer;
        return Colors.color.onSurface;
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Tokens.radius.full
        color: root.checked ? Chrome.tonal.bg : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Motion.short()
                easing.bezierCurve: Motion.easingStandard
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.full
        color: root.close ? Colors.color.error : Colors.color.primary
        opacity: Chrome.stateLayer(hover.hovered, ma.pressed)

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.short()
                easing.bezierCurve: Motion.easingStandard
            }
        }
    }

    HoverHandler {
        id: hover
        enabled: root.enabled
    }

    MIcon {
        anchors.centerIn: parent
        name: root.iconName
        size: root.iconSize
        color: root._iconColor
        tint: true
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            root.forceActiveFocus();
            if (mouse.button === Qt.MiddleButton)
                root.middleClicked();
            else if (mouse.button === Qt.RightButton)
                root.rightClicked();
            else
                root.clicked();
        }
        onWheel: (w) => root.wheel(w.angleDelta.y > 0 ? 1 : -1)
    }

    MFocusRing {
        radius: Tokens.radius.full
    }
}
