import QtQuick
import "../../../../Widgets"
import "../../../../Services"
import "../../../../Commons"

Item {
    implicitWidth: Tokens.spacing.xxl
    implicitHeight: Tokens.spacing.xxl

    MIconButton {
        anchors.centerIn: parent
        iconName: "preferences-system-symbolic"
        key: "bar.settings"
        onClicked: Notifications.toggle()
    }
}
