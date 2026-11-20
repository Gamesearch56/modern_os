import QtQuick
import "../../Commons"
import "../../Widgets"
import "../../Services"

MPopup {
    id: root

    width: Tokens.spacing.xxl * 8
    height: Math.max(column.implicitHeight, Tokens.spacing.xxl * 8) + Tokens.spacing.md * 2

    Column {
        id: column
        spacing: Tokens.spacing.xs
        width: parent.width
        Repeater {
            model: [
                { key: "files.sort.name", value: "name" },
                { key: "files.sort.created", value: "created" },
                { key: "files.sort.updated", value: "updated" },
                { key: "files.sort.size", value: "size" }
            ]
            delegate: MListItem {
                required property var modelData
                width: parent.width
                height: implicitHeight
                compact: true
                titleKey: modelData.key
                selected: Files.sortKey === modelData.value || (modelData.value === "updated" && Files.sortKey === "modified")
                onClicked: Files.setSort(modelData.value, Files.sortDesc, Files.foldersFirst)
            }
        }
        MDivider {
            width: parent.width
            height: Tokens.stroke.hairline
        }
        MListItem {
            width: parent.width
            height: implicitHeight
            compact: true
            titleKey: "files.sort.asc"
            selected: !Files.sortDesc
            onClicked: Files.setSort(Files.sortKey, false, Files.foldersFirst)
        }
        MListItem {
            width: parent.width
            height: implicitHeight
            compact: true
            titleKey: "files.sort.desc"
            selected: Files.sortDesc
            onClicked: Files.setSort(Files.sortKey, true, Files.foldersFirst)
        }
        MDivider {
            width: parent.width
            height: Tokens.stroke.hairline
        }
        MListItem {
            width: parent.width
            height: implicitHeight
            compact: true
            titleKey: "files.sort.foldersFirst"
            onClicked: Files.setSort(Files.sortKey, Files.sortDesc, !Files.foldersFirst)
            MSwitch {
                compact: true
                checked: Files.foldersFirst
                onToggled: (on) => Files.setSort(Files.sortKey, Files.sortDesc, on)
            }
        }
        MListItem {
            width: parent.width
            height: implicitHeight
            compact: true
            titleKey: "files.sort.showHidden"
            onClicked: Files.toggleHidden()
            MSwitch {
                compact: true
                checked: Files.showHidden
                onToggled: (on) => {
                    if (on !== Files.showHidden)
                        Files.toggleHidden();
                }
            }
        }
    }
}
