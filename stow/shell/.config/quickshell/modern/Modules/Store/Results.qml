import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Item {
    id: root

    readonly property bool installed: Store.categoryId === "installed" && Store.query.trim().length === 0
    readonly property bool empty: !Store.loading && Store.results.length === 0 && (!root.installed || Store.systemPkgs.length === 0)

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.md

        MText {
            visible: Store.query.trim().length > 0
            key: "store.resultsTitle"
            params: ({ q: Store.query.trim() })
            styleName: "titleMedium"
            Layout.fillWidth: true
        }

        MText {
            visible: Store.query.trim().length === 0
            key: "store.categories." + Store.categoryId
            styleName: "titleMedium"
            Layout.fillWidth: true
        }

        MLinearProgress {
            visible: Store.loading
            Layout.fillWidth: true
            indeterminate: true
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Tokens.spacing.xs
            reuseItems: true
            boundsBehavior: Flickable.StopAtBounds
            model: Store.results.length
            visible: !root.empty && !root.installed
            delegate: PkgRow {
                required property int index
                width: ListView.view.width
                pkg: Store.results[index] || ({})
                removable: !Store.isSystem(String(pkg && pkg.name || ""))
            }
        }

        Flickable {
            visible: !root.empty && root.installed
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: installedCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: installedCol
                width: parent.width
                spacing: Tokens.spacing.xs

                Repeater {
                    model: Store.results.length
                    PkgRow {
                        required property int index
                        Layout.fillWidth: true
                        pkg: Store.results[index] || ({})
                    }
                }

                SystemGroup {
                    packages: Store.systemPkgs
                }
            }
        }

        MEmptyState {
            visible: root.empty
            Layout.fillWidth: true
            Layout.fillHeight: true
            iconName: "system-software-install-symbolic"
            titleKey: "store.empty"
            hintKey: Store.query.trim().length > 0 ? "store.emptySearch" : "store.emptyHint"
        }
    }
}
