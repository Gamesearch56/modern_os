import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

ColumnLayout {
    id: root

    property string query: ""
    property string categoryId: "applications"
    property alias flick: list
    readonly property var items: CheatsheetModel.itemsFor(root.categoryId, root.query)

    spacing: Tokens.spacing.md

    MText {
        key: "cheatsheet.category." + root.categoryId
        styleName: "headlineSmall"
        Layout.fillWidth: true
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        Flickable {
            id: list
            anchors.fill: parent
            clip: true
            contentWidth: width
            contentHeight: col.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            visible: root.items.length > 0

            ColumnLayout {
                id: col
                width: parent.width
                spacing: Tokens.spacing.xxs

                Repeater {
                    model: root.items.length
                    delegate: MListItem {
                        required property int index
                        readonly property var bind: root.items[index] || ({})
                        Layout.fillWidth: true
                        hoverHighlight: false
                        keyStop: true
                        titleKey: "cheatsheet.action." + bind.action

                        Row {
                            spacing: Tokens.spacing.xs
                            Repeater {
                                model: bind.caps || []
                                MKeycap {
                                    required property int index
                                    value: (bind.caps || [])[index] || ""
                                }
                            }
                        }
                    }
                }
            }
        }

        MEmptyState {
            visible: root.items.length === 0
            anchors.fill: parent
            iconName: "input-keyboard"
            titleKey: "cheatsheet.noResults"
        }
    }
}
