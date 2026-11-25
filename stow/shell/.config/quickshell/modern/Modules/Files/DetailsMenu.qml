import QtQuick
import "../../Commons"
import "../../Widgets"
import "../../Services"

MPopup {
    id: root

    width: Tokens.spacing.xxl * 8
    height: column.implicitHeight + Tokens.spacing.md * 2
    onOpenChanged: Files.cover(open)

    Column {
        id: column
        spacing: Tokens.spacing.xs
        width: parent.width
        Repeater {
            model: [
                { key: "files.details.size", name: "size", icon: "measure", on: Files.showSize },
                { key: "files.details.created", name: "created", icon: "view-pim-calendar", on: Files.showCreated },
                { key: "files.details.updated", name: "modified", icon: "document-open-recent", on: Files.showModified },
                { key: "files.details.type", name: "type", icon: "text-x-generic", on: Files.showType }
            ]
            delegate: MListItem {
                required property var modelData
                width: parent.width
                height: implicitHeight
                compact: true
                iconName: modelData.icon
                titleKey: modelData.key
                onClicked: Files.setDetail(modelData.name, !modelData.on)
                MSwitch {
                    compact: true
                    checked: modelData.on
                    onToggled: (on) => Files.setDetail(modelData.name, on)
                }
            }
        }
        MDivider {
            width: parent.width
            height: Tokens.stroke.hairline
        }
        Repeater {
            model: [
                { key: "files.places.recent", name: "recent", icon: "document-open-recent", on: Files.showRecent, place: "recent" },
                { key: "files.places.network", name: "network", icon: "network-workgroup", on: Files.showNetwork, place: "network" }
            ]
            delegate: MListItem {
                required property var modelData
                width: parent.width
                height: implicitHeight
                compact: true
                iconName: modelData.icon
                titleKey: modelData.key
                onClicked: root._place(modelData, !modelData.on)
                MSwitch {
                    compact: true
                    checked: modelData.on
                    onToggled: (on) => root._place(modelData, on)
                }
            }
        }
    }

    function _place(row: var, on: bool) {
        Files.setDetail(row.name, on);
        if (!on && Files.place === row.place)
            Files.home();
    }
}
