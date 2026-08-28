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

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.sm

        MSearchField {
            id: search
            Layout.fillWidth: true
            placeholderKey: "settings.search"
            onTextEdited: root.query = text
        }

        ListView {
            id: nav
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Tokens.spacing.xxs
            model: root.catalog.filtered(root.query)
            delegate: Item {
                required property var modelData
                width: nav.width
                height: modelData.kind === "group" ? Tokens.spacing.xl : itemRow.implicitHeight

                MText {
                    visible: modelData.kind === "group"
                    anchors.fill: parent
                    key: modelData.key
                    styleName: "labelSmall"
                    color: Colors.color.onSurfaceVariant
                    font.capitalization: Font.AllUppercase
                }

                MListItem {
                    id: itemRow
                    visible: modelData.kind === "item"
                    width: nav.width
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
