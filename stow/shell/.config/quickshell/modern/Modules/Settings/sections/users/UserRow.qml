import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

ColumnLayout {
    id: root

    required property var person
    property bool busy: false

    signal editClicked(var person)
    signal removeClicked(var person)

    readonly property bool admin: Passwd.isAdmin(root.person)
    readonly property bool canDelete: Passwd.canDelete(root.person.login || "")
    readonly property real actionWidth: Tokens.spacing.xxl * 2 + Tokens.spacing.sm

    spacing: Tokens.spacing.sm
    Layout.fillWidth: true

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md

        MAvatar {
            size: Tokens.icon.md
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            MText {
                value: person.gecos || person.login || ""
                styleName: "bodyLarge"
                Layout.fillWidth: true
            }
            MText {
                value: person.login || ""
                styleName: "bodySmall"
                color: Colors.color.onSurfaceVariant
                Layout.fillWidth: true
            }
        }

        MText {
            key: root.admin ? "settings.users.adminYes" : "settings.users.adminNo"
            styleName: "bodySmall"
            color: Colors.color.onSurfaceVariant
            Layout.alignment: Qt.AlignVCenter
        }

        RowLayout {
            visible: Passwd.canManage
            Layout.preferredWidth: Passwd.canManage ? root.actionWidth : 0
            Layout.maximumWidth: Passwd.canManage ? root.actionWidth : 0
            Layout.alignment: Qt.AlignVCenter
            spacing: Tokens.spacing.xs
            Item { Layout.fillWidth: true }
            MIconButton {
                iconName: "document-edit-symbolic"
                key: "settings.users.editTitle"
                iconSize: Tokens.icon.md
                enabled: !root.busy
                onClicked: root.editClicked(root.person)
            }
            MIconButton {
                iconName: "edit-delete-symbolic"
                key: "settings.users.deleteUser"
                iconSize: Tokens.icon.md
                enabled: !root.busy && root.canDelete
                onClicked: root.removeClicked(root.person)
            }
        }
    }

    MDivider { Layout.fillWidth: true }
}