import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Item {
    id: root

    readonly property bool _barBottom: Config.bar.position === "bottom"
    readonly property bool _barLeft: Config.bar.position === "left"

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

    MouseArea {
        anchors.fill: parent
        onClicked: Notifications.hide()
    }

    Rectangle {
        id: card
        width: Tokens.spacing.xxl * 16
        implicitHeight: inner.implicitHeight + Tokens.spacing.md * 2
        height: Math.min(implicitHeight, parent.height - Tokens.spacing.xl)
        color: Colors.color.surface
        radius: Tokens.radius.medium
        border.color: Colors.color.outlineVariant
        border.width: Tokens.stroke.hairline
        clip: true
        opacity: Config.design.transparency ?? 0.85
        anchors.right: !root._barLeft ? parent.right : undefined
        anchors.left: root._barLeft ? parent.left : undefined
        anchors.rightMargin: Config.bar.endGap ?? Tokens.spacing.md
        anchors.leftMargin: Config.bar.endGap ?? Tokens.spacing.md
        y: root._barBottom
            ? (parent.height - height - Tokens.spacing.sm)
            : Tokens.spacing.sm
        scale: Motion.overlayScale(Notifications.panelOpen)

        Behavior on scale {
            NumberAnimation {
                duration: Motion.medium()
                easing.bezierCurve: Motion.easingEmphasizedDecelerate
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            id: inner
            anchors.fill: parent
            anchors.margins: Tokens.spacing.md
            spacing: Tokens.spacing.md

            Header {}
            Toggles {}
            Sliders {}
            Stats {}

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

            MPane {
                Layout.fillWidth: true
                Layout.preferredHeight: list.visible
                    ? Math.min(list.contentHeight + Tokens.spacing.sm * 2, Tokens.spacing.xxl * 16)
                    : Tokens.spacing.xxl * 6

                ListView {
                    id: list
                    visible: Notifications.list.length > 0
                    anchors.fill: parent
                    clip: true
                    spacing: Tokens.spacing.sm
                    model: Notifications.list
                    delegate: MListItem {
                        required property var modelData
                        width: list.width
                        tintIcon: (modelData.image || "").length === 0
                        iconName: {
                            const a = String(modelData.appIcon || "");
                            if (a.length && a.indexOf("/") === -1 && a.indexOf(":") === -1)
                                return a;
                            return "dialog-information-symbolic";
                        }
                        imageSource: {
                            const img = modelData.image || "";
                            if (!img.length)
                                return "";
                            return String(img).indexOf("://") !== -1 ? String(img) : ("file://" + img);
                        }
                        imageSize: Tokens.icon.lg
                        titleValue: modelData.summary || modelData.appName || ""
                        subtitleValue: modelData.body || ""
                        MIconButton {
                            close: true
                            iconName: "window-close"
                            key: "bar.close"
                            size: Tokens.spacing.xl
                            iconSize: Tokens.icon.sm
                            onClicked: Notifications.dismiss(modelData)
                        }
                    }
                }

                MEmptyState {
                    visible: Notifications.list.length === 0
                    anchors.fill: parent
                    iconName: "preferences-system-notifications-symbolic"
                    titleKey: "notifications.empty"
                }
            }
        }
    }
}
