import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

ColumnLayout {
    implicitWidth: Tokens.spacing.xxl * 12
    spacing: Tokens.spacing.sm

    Repeater {
        model: Notifications.list.slice(0, 3)

        MCard {
            required property var modelData
            Layout.fillWidth: true
            Layout.preferredHeight: Tokens.spacing.xxl * 3
            level: 2
            borderWidth: toastHover.hovered ? 2 : 1
            borderColor: toastHover.hovered ? Colors.color.primary : Colors.color.outlineVariant

            HoverHandler {
                id: toastHover
            }

            RowLayout {
                anchors.fill: parent
                spacing: Tokens.spacing.sm

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.xs

                    MText {
                        Layout.fillWidth: true
                        value: modelData.summary || modelData.appName || ""
                        styleName: "titleSmall"
                    }

                    MText {
                        Layout.fillWidth: true
                        value: modelData.body || ""
                        styleName: "bodySmall"
                        color: Colors.color.onSurfaceVariant
                        wrapMode: Text.WordWrap
                    }
                }

                MIconButton {
                    iconName: "window-close"
                    onClicked: Notifications.dismiss(modelData)
                }
            }
        }
    }
}
