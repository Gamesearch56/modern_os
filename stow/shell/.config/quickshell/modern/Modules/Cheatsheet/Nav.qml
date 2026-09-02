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

    function focusSearch() {
        search.forceActiveFocus();
    }

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
        case "mouse":
            return "input-mouse";
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
                    model: root.cats.length
                    delegate: MListItem {
                        required property int index
                        readonly property var cat: root.cats[index] || ({})
                        Layout.fillWidth: true
                        variant: "nav"
                        iconName: root.iconFor(cat.id)
                        titleKey: "cheatsheet.category." + cat.id
                        selected: root.categoryId === cat.id
                        onClicked: root.picked(cat.id)
                    }
                }
            }
        }
    }
}
