import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Item {
    id: root

    Rectangle {
        anchors.fill: parent
        color: Colors.color.scrim
        opacity: 0.32
        MouseArea {
            anchors.fill: parent
            onClicked: Notifications.hide()
        }
    }

    MCard {
        id: card
        level: 3
        width: Math.min(Tokens.spacing.xxl * 12, parent.width - Tokens.spacing.lg)
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: Tokens.spacing.md

        ColumnLayout {
            anchors.fill: parent
            spacing: Tokens.spacing.md

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.sm

                MText {
                    key: "quickSettings.title"
                    styleName: "titleMedium"
                    Layout.fillWidth: true
                }

                MText {
                    key: "notifications.dnd"
                    styleName: "labelMedium"
                    color: Colors.color.onSurfaceVariant
                }

                MSwitch {
                    checked: Notifications.dnd
                    onToggled: (v) => Notifications.dnd = v
                }
            }

            QuickSettings {
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true

                MText {
                    key: "bar.notifications"
                    styleName: "titleSmall"
                    Layout.fillWidth: true
                }

                MButton {
                    kind: "text"
                    key: "notifications.clearAll"
                    enabled: Notifications.list.length > 0
                    onClicked: Notifications.dismissAll()
                }
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Tokens.spacing.xs
                model: Notifications.list
                delegate: MListItem {
                    required property var modelData
                    width: ListView.view.width
                    titleValue: modelData.summary || modelData.appName || ""
                    subtitleValue: modelData.body || ""
                    onClicked: Notifications.dismiss(modelData)
                }
            }

            MText {
                visible: Notifications.list.length === 0
                key: "notifications.empty"
                styleName: "bodyMedium"
                color: Colors.color.onSurfaceVariant
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }
}
