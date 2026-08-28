// MD3 slider. `from`/`to`/`value` in, `moved(real)` on drag. Used by
// audio (volume) and brightness; the bar itself never inlines a
// Rectangle-as-slider. Shift is handled by the caller (fine step).
import QtQuick
import "../Commons"

Item {
    id: root

    property real from: 0
    property real to: 100
    property real value: 0
    property bool enabled: true

    signal moved(real value)

    implicitWidth: Tokens.spacing.xxl * 6
    implicitHeight: Tokens.spacing.xl
    opacity: root.enabled ? 1 : 0.38

    readonly property real _span: Math.max(0.0001, root.to - root.from)
    readonly property real _ratio: Math.max(0, Math.min(1, (root.value - root.from) / root._span))

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        height: Tokens.spacing.xs
        radius: Tokens.radius.full
        color: Colors.color.surfaceVariant
    }

    Rectangle {
        anchors.verticalCenter: track.verticalCenter
        anchors.left: track.left
        width: track.width * root._ratio
        height: track.height
        radius: track.radius
        color: Colors.color.primary
    }

    Rectangle {
        id: thumb
        width: Tokens.spacing.lg
        height: Tokens.spacing.lg
        radius: Tokens.radius.full
        color: Colors.color.primary
        anchors.verticalCenter: track.verticalCenter
        x: (parent.width - width) * root._ratio
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onPressed: (mouse) => root._setFromX(mouse.x)
        onPositionChanged: (mouse) => {
            if (pressed)
                root._setFromX(mouse.x);
        }
    }

    function _setFromX(px: real) {
        const r = Math.max(0, Math.min(1, px / Math.max(1, root.width)));
        root.moved(root.from + r * root._span);
    }
}
