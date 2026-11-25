import QtQuick
import "../../Commons"
import "../../Widgets"
import "../../Services"

MPopup {
    id: root

    width: Tokens.spacing.xxl * 7
    height: column.implicitHeight + Tokens.spacing.md * 2
    onOpenChanged: Files.cover(open)

    Column {
        id: column
        spacing: Tokens.spacing.xs
        width: parent.width

        MListItem {
            width: parent.width
            height: implicitHeight
            compact: true
            iconName: "folder-new"
            titleKey: "files.menu.newFolder"
            onClicked: { root.open = false; Files.askName("dir"); }
        }
        MListItem {
            width: parent.width
            height: implicitHeight
            compact: true
            iconName: "document-new"
            titleKey: "files.menu.newFile"
            onClicked: { root.open = false; Files.askName("file"); }
        }
    }
}
