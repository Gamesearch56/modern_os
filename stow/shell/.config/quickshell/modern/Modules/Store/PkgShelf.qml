import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

ColumnLayout {
    id: root

    property var section: ({})

    readonly property string sectionId: String(section && section.id || "")
    readonly property var packages: section && section.packages ? section.packages : []
    readonly property int columns: 6

    spacing: Tokens.spacing.sm
    Layout.fillWidth: true

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md

        MSectionHeader {
            key: "store.categories." + root.sectionId
            styleName: "titleMedium"
            topMargin: 0
            Layout.fillWidth: true
        }

        MButton {
            visible: root.sectionId.length > 0
            kind: "text"
            key: "store.seeAll"
            iconName: "go-next"
            iconAfter: true
            onClicked: Store.setCategory(root.sectionId)
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: root.columns
        columnSpacing: Tokens.spacing.xs
        rowSpacing: Tokens.spacing.sm

        Repeater {
            model: root.packages.length

            PkgTile {
                required property int index
                Layout.fillWidth: true
                Layout.preferredHeight: Tokens.store.tile + Tokens.spacing.xl
                pkg: root.packages[index] || ({})
            }
        }
    }
}
