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
    property bool busy: false

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
    Accessible.onPressAction: {
        if (root.enabled && !root.busy)
            root.clicked();
    }

    Keys.onPressed: (event) => {
        if (root.busy || !root.enabled)
            return;
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

    readonly property real _layer: Chrome.stateLayer(root._hover && !root.checked && !root.busy, ma.pressed && !root.checked && !root.busy)

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.full
        color: Chrome.tonal.bg
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
        id: glyph
        anchors.centerIn: parent
        name: root.iconName
        source: root.iconSource
        size: root.iconSize
        color: root._iconColor
        tint: root.tint
        RotationAnimation on rotation {
            running: root.busy
            from: 0
            to: 360
            duration: Motion.extraLongMs
            loops: Animation.Infinite
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: root.enabled && !root.busy
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

    onBusyChanged: {
        if (!root.busy)
            glyph.rotation = 0;
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
