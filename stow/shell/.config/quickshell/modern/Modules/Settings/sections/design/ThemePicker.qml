import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

Flow {
    id: root
    Layout.fillWidth: true
    spacing: Tokens.spacing.sm

    property bool createOpen: false
    property string newName: ""

    Connections {
        target: Theme
        function onCreated(path) {
            Notifications.toast(I18n.t("settings.themeCreated"), path);
        }
    }

    Repeater {
        model: Theme.slugs.length
        MCard {
            required property int index
            readonly property string slug: String(Theme.slugs[index] || "")
            readonly property bool active: slug === Config.design.activeProfile
            width: Tokens.spacing.xxl * 5
            implicitHeight: Tokens.spacing.xxl * 3
            level: active ? 3 : 1
            highlighted: active

            ColumnLayout {
                anchors.fill: parent
                spacing: Tokens.spacing.xs
                MText {
                    value: slug
                    styleName: "labelLarge"
                }
                Row {
                    spacing: Tokens.spacing.xs
                    Repeater {
                        model: 3
                        Rectangle {
                            required property int index
                            readonly property var _sw: [Colors.color.primary, Colors.color.secondary, Colors.color.tertiary]
                            width: Tokens.spacing.md
                            height: Tokens.spacing.md
                            radius: Tokens.radius.full
                            color: _sw[index]
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    ConfigWrite.set("design.activeProfile", slug);
                    Theme.apply("", slug);
                }
            }
        }
    }
    MIconButton {
        iconName: "list-add"
        onClicked: root.createOpen = true
    }

    MDialog {
        anchors.fill: parent
        open: root.createOpen
        titleKey: "settings.themeCreate"
        confirmKey: "settings.save"
        onConfirmed: {
            Theme.create(root.newName);
            root.newName = "";
            root.createOpen = false;
        }
        onCancelled: {
            root.newName = "";
            root.createOpen = false;
        }
        MTextField {
            placeholderKey: "settings.themeName"
            onTextEdited: root.newName = text
        }
    }
}
