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
    readonly property int columns: 3
    readonly property bool popular: root.sectionId === "popular"

    spacing: Tokens.spacing.sm
    Layout.fillWidth: true

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md

        MSectionHeader {
            key: root.popular ? "store.popular" : ("store.categories." + root.sectionId)
            styleName: "titleMedium"
            topMargin: 0
            Layout.fillWidth: true
        }

        MButton {
            visible: !root.popular && root.sectionId.length > 0
            kind: "text"
            key: "store.seeAll"
            onClicked: Store.setCategory(root.sectionId)
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: root.columns
        columnSpacing: Tokens.spacing.xs
        rowSpacing: Tokens.spacing.xs

        Repeater {
            model: root.packages.length

            PkgCard {
                required property int index
                Layout.fillWidth: true
                            Layout.preferredHeight: Tokens.spacing.xxl * 6
                pkg: root.packages[index] || ({})
            }
        }
    }
}
