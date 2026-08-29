import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    id: root
    spacing: Tokens.spacing.md

    property bool editorOpen: false
    property string draftName: User.displayName
    property string draftPassword: ""

    Item {
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: Tokens.spacing.xxl * 4
        implicitHeight: Tokens.spacing.xxl * 4

        MAvatar {
            anchors.centerIn: parent
            size: Tokens.spacing.xxl * 3
            source: User.faceUrl
        }

        MIconButton {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            iconName: "document-edit"
            onClicked: root.editorOpen = true
        }
    }

    MText {
        Layout.alignment: Qt.AlignHCenter
        value: User.displayName
        styleName: "titleLarge"
    }

    MDialog {
        anchors.fill: parent
        open: root.editorOpen
        titleKey: "settings.users.editTitle"
        confirmKey: "settings.save"
        onConfirmed: {
            Passwd.setDisplayName(root.draftName);
            if (root.draftPassword.length > 0)
                Passwd.setPassword(root.draftPassword);
            root.draftPassword = "";
            root.editorOpen = false;
        }
        onCancelled: {
            root.draftPassword = "";
            root.editorOpen = false;
        }

        ColumnLayout {
            spacing: Tokens.spacing.md
            MField {
                labelKey: "settings.users.displayName"
                MTextField {
                    text: root.draftName
                    onTextEdited: root.draftName = text
                }
            }
            MField {
                labelKey: "session.password"
                MTextField {
                    echoMode: TextInput.Password
                    onTextEdited: root.draftPassword = text
                }
            }
        }
    }

    MSectionHeader { key: "settings.users.all" }
    Repeater {
        model: Passwd.users
        MListItem {
            required property var modelData
            Layout.fillWidth: true
            titleValue: modelData.gecos || modelData.login
            subtitleValue: modelData.login
        }
    }

    MSectionHeader { key: "settings.users.groups" }
    Repeater {
        model: Passwd.groups
        MListItem {
            required property var modelData
            Layout.fillWidth: true
            titleValue: String(modelData)
            iconName: "dialog-ok"
        }
    }

    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.autologin"
        MSwitch {
            checked: !!(Config.general.autologin)
            onToggled: (v) => ConfigWrite.set("general.autologin", v)
        }
    }
}
