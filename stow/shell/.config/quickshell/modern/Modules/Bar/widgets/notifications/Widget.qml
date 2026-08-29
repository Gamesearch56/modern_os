import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

Item {
    implicitWidth: Tokens.spacing.xxl
    implicitHeight: Tokens.spacing.xxl

    MIconButton {
        anchors.centerIn: parent
        iconName: Notifications.unread > 0 ? "notifications-symbolic" : "notifications-disabled-symbolic"
        key: "bar.notifications"
        onClicked: Notifications.toggle()
    }

    Rectangle {
        visible: Notifications.unread > 0
        anchors.right: parent.right
        anchors.top: parent.top
        width: Tokens.spacing.md
        height: Tokens.spacing.md
        radius: Tokens.radius.full
        color: Colors.color.error

        MText {
            anchors.centerIn: parent
            value: String(Notifications.unread)
            styleName: "labelSmall"
            color: Colors.color.onError
        }
    }
}
