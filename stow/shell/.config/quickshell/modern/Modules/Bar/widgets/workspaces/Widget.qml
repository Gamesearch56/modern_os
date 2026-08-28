import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

Row {
    spacing: Tokens.spacing.xxs

    Repeater {
        model: Hypr.workspaces

        Rectangle {
            required property var modelData
            width: Tokens.spacing.xl
            height: Tokens.spacing.xl
            radius: Tokens.radius.full
            color: modelData.focused ? Colors.color.primary : (modelData.urgent ? Colors.color.error : Colors.color.surfaceContainerHighest)

            MText {
                anchors.centerIn: parent
                value: String(modelData.id)
                styleName: "labelSmall"
                color: modelData.focused ? Colors.color.onPrimary : Colors.color.onSurface
            }

            MouseArea {
                anchors.fill: parent
                onClicked: Hypr.focusWorkspace(modelData.id)
                cursorShape: Qt.PointingHandCursor
            }
        }
    }
}
