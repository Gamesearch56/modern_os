import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

ColumnLayout {
    id: root

    spacing: Tokens.spacing.sm
    Layout.fillWidth: true

    readonly property real adminWidth: Tokens.spacing.xxl * 3
    readonly property real loginWidth: Tokens.spacing.xxl * 4

    signal terminalRequested(string login)

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md

        MText {
            key: "settings.users.username"
            styleName: "labelLarge"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MText {
            key: "settings.users.colAdmin"
            styleName: "labelLarge"
            color: Colors.color.onSurfaceVariant
            Layout.preferredWidth: root.adminWidth
            Layout.maximumWidth: root.adminWidth
        }
        MText {
            key: "settings.users.login"
            styleName: "labelLarge"
            color: Colors.color.onSurfaceVariant
            horizontalAlignment: Text.AlignHCenter
            Layout.preferredWidth: root.loginWidth
            Layout.maximumWidth: root.loginWidth
        }
    }
    MDivider { Layout.fillWidth: true }

    Repeater {
        model: Passwd.others.length
        RowLayout {
            required property int index
            readonly property var person: Passwd.others[index] || ({})
            readonly property bool admin: {
                const g = person.groups || [];
                return g.indexOf("wheel") !== -1 || g.indexOf("sudo") !== -1;
            }
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.xs
            Layout.bottomMargin: Tokens.spacing.xs
            spacing: Tokens.spacing.md

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                MText {
                    value: person.gecos || person.login || ""
                    styleName: "bodyMedium"
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
                key: admin ? "settings.users.adminYes" : "settings.users.adminNo"
                styleName: "bodySmall"
                Layout.preferredWidth: root.adminWidth
                Layout.maximumWidth: root.adminWidth
                Layout.alignment: Qt.AlignVCenter
            }
            Item {
                Layout.preferredWidth: root.loginWidth
                Layout.maximumWidth: root.loginWidth
                implicitHeight: loginBtn.implicitHeight
                MButton {
                    id: loginBtn
                    anchors.centerIn: parent
                    kind: "tonal"
                    key: "settings.users.login"
                    onClicked: root.terminalRequested(person.login || "")
                }
            }
        }
    }
}
