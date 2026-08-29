import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"

Item {
    id: root

    property var actions: []
    property int focusIndex: 0

    signal chosen(int index)

    Flickable {
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: col.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: col
            width: parent.width
            spacing: Tokens.spacing.xxs

            Repeater {
                model: root.actions
                delegate: MListItem {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    variant: "nav"
                    iconName: modelData.icon
                    titleKey: "powerMenu." + modelData.id
                    selected: root.focusIndex === index
                    onClicked: root.chosen(index)
                }
            }
        }
    }
}
