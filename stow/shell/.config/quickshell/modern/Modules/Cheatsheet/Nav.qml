import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Item {
    id: root

    property string categoryId: "applications"
    readonly property var cats: CheatsheetModel.categories(search.text)

    signal queryEdited(string text)
    signal picked(string id)

    function iconFor(id: string): string {
        switch (id) {
        case "system":
            return "preferences-system";
        case "utilities":
            return "applications-utilities";
        case "screenshots":
            return "camera-photo";
        case "windowManagement":
            return "preferences-system-windows";
        case "workspaces":
            return "view-grid";
        default:
            return "view-app-grid-symbolic";
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.sm

        MSearchField {
            id: search
            Layout.fillWidth: true
            placeholderKey: "cheatsheet.search"
            onTextEdited: root.queryEdited(text)
            Component.onCompleted: forceActiveFocus()
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
                    model: root.cats
                    delegate: MListItem {
                        required property var modelData
                        Layout.fillWidth: true
                        variant: "nav"
                        iconName: root.iconFor(modelData.id)
                        titleKey: "cheatsheet.category." + modelData.id
                        selected: root.categoryId === modelData.id
                        onClicked: root.picked(modelData.id)
                    }
                }
            }
        }
    }
}
