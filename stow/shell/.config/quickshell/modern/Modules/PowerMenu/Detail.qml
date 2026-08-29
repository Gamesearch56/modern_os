import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

ColumnLayout {
    id: root

    property var action: ({ id: "lock", kind: "tonal", icon: "system-lock-screen" })

    signal confirmed()

    spacing: Tokens.spacing.md

    MText {
        key: "settings.nav.session"
        styleName: "labelSmall"
        color: Colors.color.onSurfaceVariant
        font.capitalization: Font.AllUppercase
    }

    MText {
        key: "powerMenu." + (root.action.id || "lock")
        styleName: "headlineSmall"
        Layout.fillWidth: true
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Tokens.spacing.md

            MAvatar {
                Layout.alignment: Qt.AlignHCenter
                size: Tokens.spacing.xxl * 3
                source: User.faceUrl
            }

            MText {
                Layout.alignment: Qt.AlignHCenter
                value: User.displayName
                styleName: "titleLarge"
            }
        }
    }

    MButton {
        Layout.fillWidth: true
        kind: root.action.kind || "filled"
        iconName: root.action.icon || ""
        key: "powerMenu." + (root.action.id || "lock")
        onClicked: root.confirmed()
    }
}
