import QtQuick
import "../../../../Widgets"
import "../../../../Services"
import "../../../../Commons"

Item {
    implicitWidth: Config.bar.height
    implicitHeight: Config.bar.height

    MIconButton {
        anchors.fill: parent
        iconName: "org.gnome.Settings-symbolic"
        key: "bar.settings"
        checked: Notifications.panelOpen
        onClicked: Notifications.toggle()
    }
}
