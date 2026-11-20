import QtQuick
import "../../Commons"
import "../../Widgets"
import "../../Services"

MPopup {
    id: root

    width: Tokens.spacing.xxl * 8
    height: column.implicitHeight + Tokens.spacing.md * 2

    Column {
        id: column
        spacing: Tokens.spacing.xs
        width: parent.width
        Repeater {
            model: [
                { key: "files.details.size", name: "size", on: Files.showSize },
                { key: "files.details.created", name: "created", on: Files.showCreated },
                { key: "files.details.updated", name: "modified", on: Files.showModified },
                { key: "files.details.type", name: "type", on: Files.showType }
            ]
            delegate: MListItem {
                required property var modelData
                width: parent.width
                height: implicitHeight
                compact: true
                titleKey: modelData.key
                onClicked: Files.setDetail(modelData.name, !modelData.on)
                MSwitch {
                    compact: true
                    checked: modelData.on
                    onToggled: (on) => Files.setDetail(modelData.name, on)
                }
            }
        }
    }
}
