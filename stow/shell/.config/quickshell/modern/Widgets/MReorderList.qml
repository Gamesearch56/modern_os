// Drag-to-reorder a string list. Parent owns persistence.
import QtQuick
import QtQuick.Layouts
import "../Commons"

ColumnLayout {
    id: root

    property var items: []
    property var labelKey: function (id) { return String(id); }

    signal reordered(var next)
    signal itemClicked(string id)

    spacing: Tokens.spacing.xxs

    Repeater {
        model: (root.items || []).length

        delegate: Item {
            id: row
            required property int index
            readonly property string itemId: String((root.items || [])[index] || "")
            Layout.fillWidth: true
            implicitHeight: Tokens.spacing.xxl + Tokens.spacing.md
            z: drag.drag.active ? 2 : 0

            MListItem {
                id: tile
                width: row.width
                height: row.implicitHeight
                titleKey: root.labelKey(row.itemId)
                iconName: "view-list"
                onClicked: root.itemClicked(row.itemId)

                MouseArea {
                    id: drag
                    anchors.right: parent.right
                    width: Tokens.spacing.xxl
                    height: parent.height
                    cursorShape: Qt.SizeVerCursor
                    drag.target: tile
                    drag.axis: Drag.YAxis
                    onReleased: {
                        tile.y = 0;
                        const h = row.implicitHeight + Tokens.spacing.xxs;
                        if (h <= 0)
                            return;
                        const delta = Math.round(tile.y / h);
                        const from = row.index;
                        let to = from + delta;
                        const n = (root.items || []).length;
                        if (to < 0)
                            to = 0;
                        if (to > n - 1)
                            to = n - 1;
                        if (to === from)
                            return;
                        const next = (root.items || []).slice();
                        const taken = next.splice(from, 1)[0];
                        next.splice(to, 0, taken);
                        root.reordered(next);
                    }
                }
            }
        }
    }
}
