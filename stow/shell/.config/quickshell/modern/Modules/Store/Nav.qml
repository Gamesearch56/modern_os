// Store sidebar: package search + category filters.
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Item {
    id: root

    readonly property var mainCats: {
        void Store.categories;
        const all = Store.categories || [];
        const out = [];
        for (let i = 0; i < all.length; i++) {
            if (all[i].id !== "installed")
                out.push(all[i]);
        }
        return out;
    }
    readonly property var installedCats: {
        void Store.categories;
        const all = Store.categories || [];
        const out = [];
        for (let i = 0; i < all.length; i++) {
            if (all[i].id === "installed")
                out.push(all[i]);
        }
        return out;
    }

    function focusSearch() {
        search.focusToType();
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.md

        MSearchField {
            id: search
            Layout.fillWidth: true
            placeholderKey: "store.search"
            onTextEdited: Store.setQuery(text)
            Component.onCompleted: {
                if (Store.query.length > 0)
                    text = Store.query;
            }
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
                    model: root.mainCats.length

                    delegate: MListItem {
                        id: row
                        required property int index
                        readonly property var rowData: root.mainCats[index] || ({})
                        Layout.fillWidth: true
                        variant: "nav"
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
                    model: root.installedCats.length

                    delegate: MListItem {
                        id: installedRow
                        required property int index
                        readonly property var rowData: root.installedCats[index] || ({})
                        Layout.fillWidth: true
                        variant: "nav"
                        iconName: installedRow.rowData.icon || Store.iconFor(installedRow.rowData.id)
                        titleKey: "store.categories." + (installedRow.rowData.id || "")
                        selected: Store.categoryId === installedRow.rowData.id && Store.query.trim().length === 0
                        onClicked: Store.setCategory(installedRow.rowData.id)
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
