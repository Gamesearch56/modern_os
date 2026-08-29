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
    readonly property var rows: root.catalog ? root.catalog.filtered(root.query) : []

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.sm

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
                    model: root.rows

                    delegate: Item {
                        id: row
                        Layout.fillWidth: true
                        implicitHeight: (modelData.kind === "group")
                            ? Tokens.spacing.xl
                            : navItem.implicitHeight
                        Layout.preferredHeight: implicitHeight

                        MText {
                            visible: modelData.kind === "group"
                            anchors.fill: parent
                            key: modelData.key || ""
                            styleName: "labelSmall"
                            color: Colors.color.onSurfaceVariant
                            font.capitalization: Font.AllUppercase
                        }

                        MListItem {
                            id: navItem
                            visible: modelData.kind === "item"
                            width: row.width
                            variant: "nav"
                            iconName: root.catalog.icon(modelData.id)
                            titleKey: "settings.sections." + modelData.id
                            selected: Settings.sectionId === modelData.id
                            onClicked: Settings.openAt(modelData.id, "")
                        }
                    }
                }
            }
        }
    }
}
