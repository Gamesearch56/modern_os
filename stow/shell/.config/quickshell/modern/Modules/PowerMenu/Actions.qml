import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"

GridLayout {
    id: root

    property var actions: []
    property int focusIndex: -1

    signal chosen(int index)

    columns: 2
    columnSpacing: Tokens.spacing.md
    rowSpacing: Tokens.spacing.md

    Repeater {
        model: root.actions
        delegate: MQuickTile {
            required property var modelData
            required property int index
            Layout.fillWidth: true
            stacked: true
            iconName: modelData.icon
            titleKey: "powerMenu." + modelData.id
            checked: root.focusIndex === index
            onClicked: root.chosen(index)
        }
    }
}
