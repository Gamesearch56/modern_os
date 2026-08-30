import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

Item {
    id: root

    property string pendingLogin: ""

    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        width: parent.width
        spacing: Tokens.spacing.md

        MCard {
            id: hero
            Layout.fillWidth: true
            level: 0
            implicitHeight: heroRow.implicitHeight + Tokens.spacing.md * 2

            RowLayout {
                id: heroRow
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: Tokens.spacing.lg

                MAvatar {
                    size: Tokens.spacing.xxl * 3
                    source: User.faceUrl
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.xs

                    MText {
                        value: User.displayName
                        styleName: "titleLarge"
                        Layout.fillWidth: true
                    }
                    MText {
                        value: User.loginName
                        styleName: "bodyMedium"
                        color: Colors.color.onSurfaceVariant
                        Layout.fillWidth: true
                    }
                    Flow {
                        Layout.fillWidth: true
                        Layout.topMargin: Tokens.spacing.sm
                        spacing: Tokens.spacing.xs
                        Repeater {
                            model: Passwd.groups.length
                            Rectangle {
                                required property int index
                                readonly property string name: Passwd.groups[index] || ""
                                implicitHeight: Tokens.spacing.xl
                                implicitWidth: lab.implicitWidth + Tokens.spacing.md * 2
                                radius: Tokens.radius.full
                                color: Colors.color.surfaceContainerHighest
                                MText {
                                    id: lab
                                    anchors.centerIn: parent
                                    value: name
                                    styleName: "labelLarge"
                                }
                            }
                        }
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
                checked: !!(Config.general.autologin)
                onToggled: (v) => ConfigWrite.set("general.autologin", v)
            }
        }

        MSectionHeader {
            key: "settings.users.others"
            topMargin: Tokens.spacing.xxl
        }
        UserTable {
            Layout.fillWidth: true
            onTerminalRequested: (login) => root.pendingLogin = login
        }

        MSectionHeader {
            key: "settings.users.groupsAll"
            topMargin: Tokens.spacing.xxl
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: Tokens.spacing.sm
            rowSpacing: Tokens.spacing.sm

            Repeater {
                model: Passwd.localGroups.length
                MCard {
                    required property int index
                    readonly property var grp: Passwd.localGroups[index] || ({})
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    level: 0
                    implicitHeight: Tokens.spacing.xxl * 2

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0
                        MText {
                            value: grp.name || ""
                            styleName: "titleSmall"
                            horizontalAlignment: Text.AlignHCenter
                            Layout.fillWidth: true
                        }
                        MText {
                            key: "settings.users.memberCount"
                            params: ({ n: (grp.members || []).length })
                            styleName: "bodySmall"
                            color: Colors.color.onSurfaceVariant
                            horizontalAlignment: Text.AlignHCenter
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }

    MDialog {
        parent: Window.window ? Window.window.contentItem : root
        anchors.fill: parent
        open: root.pendingLogin.length > 0
        titleKey: "settings.users.terminalConfirmTitle"
        titleParams: ({ user: root.pendingLogin })
        bodyKey: "settings.users.terminalConfirmBody"
        bodyParams: ({ user: root.pendingLogin })
        confirmKey: "settings.users.login"
        onConfirmed: {
            Passwd.openLogin(root.pendingLogin);
            root.pendingLogin = "";
            Settings.close();
        }
        onCancelled: root.pendingLogin = ""
    }
}
