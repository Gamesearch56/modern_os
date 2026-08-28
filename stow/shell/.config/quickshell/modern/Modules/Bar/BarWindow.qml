import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"

PanelWindow {
    id: root

    required property var screen

    anchors.top: Config.bar.position !== "bottom"
    anchors.bottom: Config.bar.position === "bottom"
    anchors.left: true
    anchors.right: true
    implicitHeight: Config.bar.height + (Config.bar.style === "floating" ? Tokens.spacing.sm * 2 : 0)
    exclusiveZone: Config.bar.autoHide ? 0 : Config.bar.height
    color: "transparent"

    Rectangle {
        id: pill
        anchors.fill: parent
        anchors.margins: Config.bar.style === "floating" ? Tokens.spacing.sm : 0
        radius: Config.bar.style === "floating" ? Tokens.radius.full : 0
        color: Colors.color.surfaceContainer
        opacity: Config.design.transparency ?? 0.85

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Tokens.spacing.md
            anchors.rightMargin: Tokens.spacing.md
            spacing: Tokens.spacing.sm

            RowLayout {
                spacing: Tokens.spacing.xs
                Repeater {
                    model: Config.bar.left
                    WidgetLoader { widgetId: modelData }
                }
            }

            Item { Layout.fillWidth: true }

            RowLayout {
                spacing: Tokens.spacing.xs
                Repeater {
                    model: Config.bar.center
                    WidgetLoader { widgetId: modelData }
                }
            }

            Item { Layout.fillWidth: true }

            RowLayout {
                spacing: Tokens.spacing.xs
                Repeater {
                    model: Config.bar.right
                    WidgetLoader { widgetId: modelData }
                }
            }
        }
    }
}
