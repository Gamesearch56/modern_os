// Settings sidebar: search + grouped nav pills.
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Item {
    id: root

    property var catalog
    property string query: ""
    readonly property var rows: {
        const c = root.catalog;
        if (!c || typeof c.filtered !== "function")
            return [];
        return c.filtered(root.query);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.md

        MSearchField {
            id: search
            Layout.fillWidth: true
            placeholderKey: "settings.search"
            onTextEdited: root.query = text
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: col.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: col
                width: parent.width
                spacing: Tokens.spacing.xxs

                Repeater {
                    model: root.rows.length

                    delegate: Item {
                        id: row
                        required property int index
                        readonly property var rowData: root.rows[index] || ({})
                        readonly property bool _group: row.rowData.kind === "group"
                        Layout.fillWidth: true
                        implicitHeight: row._group
                            ? Tokens.spacing.xl
                            : navItem.implicitHeight
                        Layout.preferredHeight: implicitHeight
                        Layout.topMargin: row._group && row.index > 0
                            ? Tokens.spacing.md
                            : 0
                        Layout.bottomMargin: row._group ? Tokens.spacing.xs : 0

                        MText {
                            visible: row._group
                            anchors.fill: parent
                            key: row.rowData.key || ""
                            styleName: "labelSmall"
                            color: Colors.color.onSurfaceVariant
                            font.capitalization: Font.AllUppercase
                        }

                        MListItem {
                            id: navItem
                            visible: !row._group
                            width: row.width
                            variant: "nav"
                            iconName: root.catalog.icon(row.rowData.id)
                            titleKey: row._group ? "" : ("settings.sections." + row.rowData.id)
                            badgeCount: row.rowData.id === "system" ? Update.pending.length : 0
                            selected: Settings.sectionId === row.rowData.id
                            onClicked: Settings.openAt(row.rowData.id, "")
                        }
                    }
                }
            }
        }
    }
}
