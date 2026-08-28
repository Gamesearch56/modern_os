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
        opacity: Notifications.panelOpen ? Tokens.overlay.scrim : 0
        MouseArea {
            anchors.fill: parent
            onClicked: Notifications.hide()
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Motion.medium()
                easing.bezierCurve: Motion.easingEmphasizedDecelerate
            }
        }
    }

    MCard {
        id: card
        level: 3
        width: Math.min(Tokens.spacing.xxl * 12, parent.width - Tokens.spacing.lg)
        implicitHeight: inner.implicitHeight + Tokens.spacing.md * 2
        height: Math.min(implicitHeight, parent.height - Tokens.spacing.xl * 2)
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Tokens.spacing.md
        opacity: Config.design.transparency ?? 0.85
        radius: Tokens.radius.large
        borderWidth: cardHover.hovered ? 2 : 1
        borderColor: cardHover.hovered ? Colors.color.primary : Colors.color.outlineVariant
        scale: Motion.overlayScale(Notifications.panelOpen)

        Behavior on scale {
            NumberAnimation {
                duration: Motion.medium()
                easing.bezierCurve: Motion.easingEmphasizedDecelerate
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Motion.medium()
                easing.bezierCurve: Motion.easingEmphasizedDecelerate
            }
        }

        HoverHandler {
            id: cardHover
        }

        ColumnLayout {
            id: inner
            anchors.fill: parent
            spacing: Tokens.spacing.md

            Header {}
            Toggles {}
            Sliders {}
            Stats {}

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

            ListView {
                id: list
                visible: Notifications.list.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, Tokens.spacing.xxl * 8)
                clip: true
                spacing: Tokens.spacing.xs
                model: Notifications.list
                delegate: MListItem {
                    required property var modelData
                    width: list.width
                    iconName: "dialog-information"
                    imageSource: {
                        const img = modelData.image || "";
                        if (!img.length)
                            return "";
                        return String(img).indexOf("://") !== -1 ? String(img) : ("file://" + img);
                    }
                    titleValue: modelData.summary || modelData.appName || ""
                    subtitleValue: modelData.body || ""
                    MIconButton {
                        close: true
                        iconName: "window-close"
                        size: Tokens.spacing.xl
                        onClicked: Notifications.dismiss(modelData)
                    }
                }
            }

            MEmptyState {
                visible: Notifications.list.length === 0
                Layout.fillWidth: true
                Layout.preferredHeight: Tokens.spacing.xxl * 4
                iconName: "preferences-system-notifications"
                titleKey: "notifications.empty"
            }
        }
    }
}
