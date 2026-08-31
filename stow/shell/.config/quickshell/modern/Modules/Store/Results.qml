import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Item {
    id: root

    readonly property bool empty: !Store.loading && Store.results.length === 0

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
            visible: !root.empty
            delegate: PkgRow {
                required property int index
                width: ListView.view.width
                pkg: Store.results[index] || ({})
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
