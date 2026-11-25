import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"

// Headings of the open chapter. The left list is every document; this
// column is the one you are reading. A click scrolls the reader to it.
ColumnLayout {
    id: root

    property var doc: null
    property var reader: null

    readonly property var heads: root.doc && root.doc.headings ? root.doc.headings : []

    spacing: Tokens.spacing.sm

    MText {
        Layout.fillWidth: true
        key: "manual.onThisPage"
        styleName: "titleSmall"
        color: Colors.color.onSurfaceVariant
    }

    Flickable {
        id: list
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        contentWidth: width
        contentHeight: col.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        Accessible.role: Accessible.List
        Accessible.name: I18n.t("manual.onThisPage")

        Column {
            id: col
            width: list.width
            spacing: Tokens.spacing.xxs

            Repeater {
                id: rows
                model: root.heads.length

                delegate: Item {
                    required property int index
                    readonly property var head: root.heads[index] || ({})
                    readonly property int level: Math.max(1, Number(head.level || 1))
                    width: col.width
                    implicitHeight: row.implicitHeight

                    MListItem {
                        id: row
                        x: (level - 1) * Tokens.spacing.md
                        width: parent.width - x
                        titleValue: String(head.text || "")
                        titleLines: 1
                        selected: !!root.reader && root.reader.headingIndex === index
                        variant: "nav"
                        compact: true
                        onClicked: {
                            if (root.reader)
                                root.reader.revealHeading(index);
                        }
                    }
                }
            }
        }
    }

    function _showCurrent() {
        if (!root.reader)
            return;
        const item = rows.itemAt(root.reader.headingIndex);
        if (!item)
            return;
        if (item.y < list.contentY)
            list.contentY = item.y;
        else if (item.y + item.height > list.contentY + list.height)
            list.contentY = item.y + item.height - list.height;
    }

    Connections {
        target: root.reader
        function onHeadingIndexChanged() { root._showCurrent(); }
    }
}
