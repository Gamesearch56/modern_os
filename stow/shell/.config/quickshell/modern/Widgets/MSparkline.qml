// Compact token-colored series. Values are numbers; empty is a hairline.
import QtQuick
import "../Commons"

Item {
    id: root

    property var values: []
    property color fillColor: Colors.color.primary
    property real barWidth: Tokens.spacing.xs

    implicitWidth: Tokens.spacing.xxl * 8
    implicitHeight: Tokens.spacing.xxl
    clip: true

    readonly property real _peak: {
        const list = root.values || [];
        let m = 0;
        for (let i = 0; i < list.length; i++) {
            const n = Number(list[i]);
            if (n > m)
                m = n;
        }
        return m;
    }

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.small
        color: Colors.color.surfaceContainerHighest
    }

    Row {
        id: row
        anchors.fill: parent
        anchors.margins: Tokens.spacing.xxs
        spacing: Tokens.spacing.xxs
        layoutDirection: Qt.LeftToRight

        Repeater {
            model: (root.values || []).length

            Rectangle {
                required property int index
                readonly property real _v: Number((root.values || [])[index] || 0)
                width: root.barWidth
                height: {
                    const peak = Math.max(1, root._peak);
                    const h = row.height * (root._v / peak);
                    return Math.max(Tokens.spacing.xxs, Math.min(row.height, h));
                }
                anchors.bottom: parent.bottom
                radius: Tokens.radius.full
                color: root.fillColor
            }
        }
    }
}
