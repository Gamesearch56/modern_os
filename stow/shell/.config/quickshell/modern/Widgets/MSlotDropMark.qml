// Insertion bar for MSlotLane while a widget is dragged between slots.
import QtQuick
import "../Commons"

Item {
    id: root

    property bool active: false
    property int insertIndex: -1
    property real rowHeight: 0
    property int count: 0

    anchors.fill: parent
    visible: root.active && root.insertIndex >= 0
    enabled: false
    z: 10

    Rectangle {
        visible: root.count === 0
        width: parent.width
        height: root.rowHeight
        radius: Tokens.radius.small
        color: Colors.color.primary
        opacity: Tokens.interaction.hover
    }

    Rectangle {
        id: bar
        width: parent.width
        height: Tokens.spacing.xs
        radius: Tokens.radius.full
        color: Colors.color.primary
        y: {
            if (root.count === 0)
                return Math.max(0, (root.rowHeight - height) / 2);
            const raw = root.insertIndex * root.rowHeight - height / 2;
            return Math.min(Math.max(0, raw), Math.max(0, parent.height - height));
        }
    }
}
