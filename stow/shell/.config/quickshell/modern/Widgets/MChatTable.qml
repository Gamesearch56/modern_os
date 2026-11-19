// Chat table. Qt's rich text drops markdown tables back to plain lines,
// so the rows are drawn here.
import QtQuick
import QtQuick.Layouts
import "../Commons"

GridLayout {
    id: root

    property var rows: []
    property var align: []

    readonly property int _cols: Math.max(1, (root.rows[0] || []).length)
    readonly property var _flat: {
        const out = [];
        const list = root.rows || [];
        for (let r = 0; r < list.length; r++) {
            const cells = list[r] || [];
            for (let c = 0; c < cells.length; c++)
                out.push({ row: r, col: c, text: String(cells[c] || "") });
        }
        return out;
    }

    columns: root._cols
    columnSpacing: 0
    rowSpacing: 0
    Layout.fillWidth: true

    function _hAlign(col: int): int {
        const a = (root.align || [])[col] || "left";
        if (a === "right")
            return Text.AlignRight;
        if (a === "center")
            return Text.AlignHCenter;
        return Text.AlignLeft;
    }

    Repeater {
        model: root._flat
        delegate: Rectangle {
            required property var modelData
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            implicitHeight: label.implicitHeight + Tokens.spacing.sm * 2
            color: modelData.row === 0 ? Colors.color.surfaceContainer : Colors.color.surfaceContainerHighest
            border.width: Tokens.stroke.hairline
            border.color: Colors.color.outlineVariant

            MText {
                id: label
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Tokens.spacing.sm
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
                value: modelData.text
                styleName: modelData.row === 0 ? "labelMedium" : "bodyMedium"
                horizontalAlignment: root._hAlign(modelData.col)
            }
        }
    }
}
