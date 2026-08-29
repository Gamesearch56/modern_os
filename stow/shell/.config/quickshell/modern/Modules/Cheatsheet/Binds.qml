import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

ColumnLayout {
    id: root

    property string query: ""
    property string categoryId: "applications"
    readonly property var items: CheatsheetModel.itemsFor(root.categoryId, root.query)

    spacing: Tokens.spacing.md

    MText {
        key: "settings.nav.input"
        styleName: "labelSmall"
        color: Colors.color.onSurfaceVariant
        font.capitalization: Font.AllUppercase
    }

    MText {
        key: "cheatsheet.category." + root.categoryId
        styleName: "headlineSmall"
        Layout.fillWidth: true
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        Flickable {
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
                    model: root.items
                    delegate: MListItem {
                        required property var modelData
                        Layout.fillWidth: true
                        titleKey: "cheatsheet.action." + modelData.action

                        Row {
                            spacing: Tokens.spacing.xs
                            Repeater {
                                model: modelData.caps
                                MKeycap {
                                    required property string modelData
                                    value: modelData
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
