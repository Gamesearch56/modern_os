import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"

ColumnLayout {
    id: root

    property var packages: []

    readonly property var _lead: root.packages.length ? root.packages[0] : ({})
    readonly property var _mid: root.packages.length > 1 ? root.packages[1] : ({})
    readonly property var _trail: root.packages.length > 2 ? root.packages[2] : ({})

    visible: root.packages.length > 0
    spacing: Tokens.spacing.sm
    Layout.fillWidth: true

    MSectionHeader {
        key: "store.featured"
        styleName: "titleMedium"
        topMargin: 0
        Layout.fillWidth: true
    }

    GridLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: Tokens.store.heroHeight
        columns: 2
        rows: 2
        columnSpacing: Tokens.spacing.sm
        rowSpacing: Tokens.spacing.sm

        HeroLead {
            pkg: root._lead
            Layout.row: 0
            Layout.column: 0
            Layout.rowSpan: 2
            Layout.columnSpan: root.packages.length === 1 ? 2 : 1
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        HeroSide {
            visible: root.packages.length > 1
            pkg: root._mid
            Layout.row: 0
            Layout.column: 1
            Layout.rowSpan: root.packages.length < 3 ? 2 : 1
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        HeroSide {
            visible: root.packages.length > 2
            pkg: root._trail
            Layout.row: 1
            Layout.column: 1
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
