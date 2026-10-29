import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

ColumnLayout {
    id: root

    signal editClicked()

    spacing: Tokens.spacing.sm
    Layout.fillWidth: true

    readonly property var person: Passwd.sessionUser || ({})
    readonly property bool admin: Passwd.isAdmin(root.person)

    MStatusCard {
        avatarSource: User.faceUrl
        avatarSize: Tokens.spacing.xxl * 2
        titleValue: User.displayName
        subtitleValue: User.loginName
        trailing: MIconButton {
            iconName: "document-edit-symbolic"
            key: "settings.users.editTitle"
            iconSize: Tokens.icon.sm
            enabled: !Passwd.running
            onClicked: root.editClicked()
        }
        detail: Flow {
            Layout.fillWidth: true
            spacing: Tokens.spacing.xs
            Rectangle {
                implicitHeight: Tokens.spacing.xl
                implicitWidth: youLab.implicitWidth + Tokens.spacing.md * 2
                radius: Tokens.radius.full
                color: Colors.color.primaryContainer
                MText {
                    id: youLab
                    anchors.centerIn: parent
                    key: "settings.users.thisAccount"
                    styleName: "labelLarge"
                    color: Colors.color.onPrimaryContainer
                }
            }
            Rectangle {
                visible: root.admin
                implicitHeight: Tokens.spacing.xl
                implicitWidth: admLab.implicitWidth + Tokens.spacing.md * 2
                radius: Tokens.radius.full
                color: Colors.color.surfaceContainerHighest
                MText {
                    id: admLab
                    anchors.centerIn: parent
                    key: "settings.users.colAdmin"
                    styleName: "labelLarge"
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.fields.autologin"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MSwitch {
            nameKey: "settings.fields.autologin"
            checked: !!(Config.general.autologin)
            enabled: Passwd.canManage && !Autologin.running
            onToggled: (v) => Autologin.setEnabled(v)
        }
    }
    MHint {
        key: "settings.hints.autologin"
        Layout.fillWidth: true
    }
    MText {
        visible: Autologin.error.length > 0 && !Autologin.running
        value: Autologin.error
        styleName: "bodySmall"
        color: Colors.color.error
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
        Accessible.role: Accessible.Alert
        Accessible.name: Autologin.error
    }
}