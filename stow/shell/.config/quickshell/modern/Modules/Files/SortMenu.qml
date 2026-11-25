import QtQuick
import "../../Commons"
import "../../Widgets"
import "../../Services"

MPopup {
    id: root

    width: Tokens.spacing.xxl * 8
    height: Math.max(column.implicitHeight, Tokens.spacing.xxl * 8) + Tokens.spacing.md * 2
    onOpenChanged: Files.cover(open)

    Column {
        id: column
        spacing: Tokens.spacing.xs
        width: parent.width
        Repeater {
            model: [
                { key: "files.sort.name", value: "name", icon: "sort-name" },
                { key: "files.sort.created", value: "created", icon: "view-pim-calendar" },
                { key: "files.sort.updated", value: "updated", icon: "document-open-recent" },
                { key: "files.sort.size", value: "size", icon: "measure" }
            ]
            delegate: MListItem {
                required property var modelData
                width: parent.width
                height: implicitHeight
                compact: true
                iconName: modelData.icon
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
            iconName: "view-sort-ascending"
            titleKey: "files.sort.asc"
            selected: !Files.sortDesc
            onClicked: Files.setSort(Files.sortKey, false, Files.foldersFirst)
        }
        MListItem {
            width: parent.width
            height: implicitHeight
            compact: true
            iconName: "view-sort-descending"
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
            iconName: "folder"
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
            iconName: "view-hidden"
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
