import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

Row {
    spacing: Tokens.spacing.xs

    Repeater {
        model: Hypr.toplevels

        Rectangle {
            required property var modelData
            visible: Hypr.focusedWorkspace && modelData.workspace && modelData.workspace.id === Hypr.focusedWorkspace.id
            height: Tokens.spacing.xl + Tokens.spacing.xs
            width: title.implicitWidth + Tokens.spacing.xl + Tokens.spacing.md
            radius: Tokens.radius.full
            color: modelData.activated ? Colors.color.primaryContainer : "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Tokens.spacing.sm
                anchors.rightMargin: Tokens.spacing.sm
                spacing: Tokens.spacing.xs

                IconImage {
                    Layout.preferredWidth: Tokens.spacing.lg
                    Layout.preferredHeight: Tokens.spacing.lg
                    source: Quickshell.iconPath(modelData.lastIpcObject?.class ?? "application-x-executable", true)
                    asynchronous: true
                }

                MText {
                    id: title
                    value: modelData.title || ""
                    styleName: "labelLarge"
                    elide: Text.ElideRight
                    Layout.maximumWidth: Tokens.spacing.xxl * 6
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: Hypr.focusWindow(modelData.address)
            }
        }
    }
}
