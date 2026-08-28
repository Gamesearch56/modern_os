import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Item {
    id: root

    Binding {
        target: SystemStats
        property: "watching"
        value: Notifications.panelOpen
    }

    Binding {
        target: Brightness
        property: "watching"
        value: Notifications.panelOpen
    }

    Rectangle {
        anchors.fill: parent
        color: Colors.color.scrim
        opacity: Tokens.overlay.scrim
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
        borderWidth: cardHover.hovered ? 2 : 1
        borderColor: cardHover.hovered ? Colors.color.primary : Colors.color.outlineVariant

        HoverHandler {
            id: cardHover
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: Tokens.spacing.md

            Header {}
            Toggles {}
            Sliders {}
            Stats {}
            MediaCard {}

            RowLayout {
                Layout.fillWidth: true
                MSectionHeader {
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

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: list
                    visible: Notifications.list.length > 0
                    anchors.fill: parent
                    clip: true
                    spacing: Tokens.spacing.xs
                    model: Notifications.list
                    delegate: MListItem {
                        required property var modelData
                        width: list.width
                        iconName: "dialog-information"
                        titleValue: modelData.summary || modelData.appName || ""
                        subtitleValue: modelData.body || ""
                        MIconButton {
                            iconName: "window-close"
                            size: Tokens.spacing.xl
                            onClicked: Notifications.dismiss(modelData)
                        }
                    }
                }

                MEmptyState {
                    visible: Notifications.list.length === 0
                    anchors.fill: parent
                    iconName: "preferences-system-notifications"
                    titleKey: "notifications.empty"
                }
            }
        }
    }
}
