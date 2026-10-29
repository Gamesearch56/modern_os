import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Flickable {
    id: root

    property var mainCats: []
    property var installedCats: []

    clip: true
    contentWidth: width
    contentHeight: col.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height

    function itemAt(pos: int): var {
        if (pos < 0)
            return null;
        if (pos < mainRepeater.count)
            return mainRepeater.itemAt(pos);
        return instRepeater.itemAt(pos - mainRepeater.count);
    }

    function reveal(item: var) {
        if (!item || !root.contentItem)
            return;
        try {
            const pos = item.mapToItem(root.contentItem, 0, 0);
            const pad = Tokens.spacing.md;
            const top = pos.y;
            const bottom = top + item.height;
            const viewTop = root.contentY;
            const viewBottom = viewTop + root.height;
            const maxY = Math.max(0, root.contentHeight - root.height);
            let y = root.contentY;
            if (top < viewTop + pad)
                y = top - pad;
            else if (bottom > viewBottom - pad)
                y = bottom - root.height + pad;
            root.contentY = Math.max(0, Math.min(maxY, y));
        } catch (e) {
        }
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: Tokens.spacing.xxs

        Repeater {
            id: mainRepeater
            model: root.mainCats.length

            delegate: MListItem {
                id: row
                required property int index
                readonly property var rowData: root.mainCats[index] || ({})
                Layout.fillWidth: true
                variant: "nav"
                tabFocus: false
                iconName: row.rowData.icon || Store.iconFor(row.rowData.id)
                titleKey: "store.categories." + (row.rowData.id || "")
                selected: Store.categoryId === row.rowData.id && Store.query.trim().length === 0
                onClicked: Store.setCategory(row.rowData.id)
            }
        }

        MDivider {
            visible: root.installedCats.length > 0
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.sm
            Layout.bottomMargin: Tokens.spacing.sm
        }

        Repeater {
            id: instRepeater
            model: root.installedCats.length

            delegate: MListItem {
                id: installedRow
                required property int index
                readonly property var rowData: root.installedCats[index] || ({})
                Layout.fillWidth: true
                variant: "nav"
                tabFocus: false
                iconName: installedRow.rowData.icon || Store.iconFor(installedRow.rowData.id)
                titleKey: "store.categories." + (installedRow.rowData.id || "")
                selected: Store.categoryId === installedRow.rowData.id && Store.query.trim().length === 0
                onClicked: Store.setCategory(installedRow.rowData.id)
            }
        }
    }
}
