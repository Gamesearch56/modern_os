import QtQuick
import "../../Commons"
import "../../Widgets"
import "actions.js" as ActionList

// File, Edit, View — the classic notepad menus, in the window header.
// Each button owns its menu so the menu opens under that button.
Row {
    id: root

    property var actions: null
    property string current: ""
    readonly property bool anyOpen: root.current.length > 0

    spacing: Tokens.spacing.xs

    function closeAll() {
        root.current = "";
    }

    Repeater {
        model: [
            { key: "editor.menu.file", menu: "file" },
            { key: "editor.menu.edit", menu: "edit" },
            { key: "editor.menu.view", menu: "view" }
        ]
        delegate: MButton {
            id: button
            required property var modelData
            kind: "text"
            key: modelData.key
            highlighted: menu.open
            onClicked: root.current = menu.open ? "" : button.modelData.menu

            Connections {
                target: root
                function onCurrentChanged() {
                    menu.open = root.current === button.modelData.menu;
                }
            }

            MActionMenu {
                id: menu
                actions: root.actions
                items: ActionList.inMenu(button.modelData.menu)
                onOpenChanged: {
                    if (!open && root.current === button.modelData.menu)
                        root.current = "";
                }
            }
        }
    }
}
