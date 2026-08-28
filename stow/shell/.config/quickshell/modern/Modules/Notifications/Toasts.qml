import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

ColumnLayout {
    id: root

    implicitWidth: Tokens.spacing.xxl * 12
    spacing: Tokens.spacing.sm

    Repeater {
        model: Notifications.list.slice(0, 3)

        MCard {
            required property var modelData
            Layout.fillWidth: true
            Layout.preferredHeight: Tokens.spacing.xxl * 3
            level: 2

            ColumnLayout {
                anchors.fill: parent
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

            MouseArea {
                anchors.fill: parent
                onClicked: Notifications.dismiss(modelData)
            }
        }
    }
}
