import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

ColumnLayout {
    id: root

    required property var grp
    property bool busy: false

    signal editClicked(var grp)
    signal removeClicked(var grp)

    readonly property bool canDelete: Passwd.canDeleteGroup(root.grp)
    readonly property real actionWidth: Tokens.spacing.xxl * 2 + Tokens.spacing.sm
    readonly property string memberLine: (grp.members || []).join(" · ")

    spacing: Tokens.spacing.sm
    Layout.fillWidth: true

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md

        MIcon {
            name: "system-users-symbolic"
            size: Tokens.icon.md
            color: Colors.color.primary
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            MText {
                value: grp.name || ""
                styleName: "bodyLarge"
                Layout.fillWidth: true
            }
            MText {
                visible: root.memberLine.length > 0
                value: root.memberLine
                styleName: "bodySmall"
                color: Colors.color.onSurfaceVariant
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            MText {
                visible: root.memberLine.length === 0
                key: "settings.users.memberCount"
                params: ({ n: 0 })
                styleName: "bodySmall"
                color: Colors.color.onSurfaceVariant
                Layout.fillWidth: true
            }
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
                key: "settings.users.editGroup"
                iconSize: Tokens.icon.md
                enabled: !root.busy
                onClicked: root.editClicked(root.grp)
            }
            MIconButton {
                iconName: "edit-delete-symbolic"
                key: "settings.users.deleteGroup"
                iconSize: Tokens.icon.md
                enabled: !root.busy && root.canDelete
                onClicked: root.removeClicked(root.grp)
            }
        }
    }

    MDivider { Layout.fillWidth: true }
}