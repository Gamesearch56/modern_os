import QtQuick
import "../../Commons"
import "../../Widgets"
import "../../Services"

MPopup {
    id: root

    property var rows: []
    property int index: -1
    property real span: Tokens.spacing.xxl * 8

    signal chosen(int index)

    width: root.span
    height: Math.max(column.implicitHeight, Tokens.spacing.xxl) + Tokens.spacing.md * 2
    onOpenChanged: Files.cover(open)

    Column {
        id: column
        width: parent.width
        spacing: Tokens.spacing.xxs

        Repeater {
            model: root.rows
            delegate: MListItem {
                required property var modelData
                required property int index
                width: column.width
                height: implicitHeight
                tabFocus: false
                iconName: modelData.dir ? "folder" : "text-x-generic"
                titleValue: modelData.name || ""
                subtitleValue: modelData.where || ""
                selected: index === root.index
                onClicked: root.chosen(index)
            }
        }
    }
}
