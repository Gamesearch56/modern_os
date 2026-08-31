// Store sidebar: package search + category filters.
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Item {
    id: root

    function focusSearch() {
        search.forceActiveFocus();
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.md

        MSearchField {
            id: search
            Layout.fillWidth: true
            placeholderKey: "store.search"
            onTextEdited: Store.setQuery(text)
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
                    model: Store.categories.length

                    delegate: MListItem {
                        id: row
                        required property int index
                        readonly property var rowData: Store.categories[index] || ({})
                        Layout.fillWidth: true
                        variant: "nav"
                        iconName: row.rowData.icon || Store.iconFor(row.rowData.id)
                        titleKey: "store.categories." + (row.rowData.id || "")
                        selected: Store.categoryId === row.rowData.id && Store.query.trim().length === 0
                        onClicked: Store.setCategory(row.rowData.id)
                    }
                }
            }
        }
    }

    Connections {
        target: Store
        function onQueryChanged() {
            if (search.text !== Store.query)
                search.text = Store.query;
        }
    }
}
