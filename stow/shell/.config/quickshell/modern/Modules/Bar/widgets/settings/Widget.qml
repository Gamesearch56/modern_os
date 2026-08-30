import QtQuick
import "../../../../Widgets"
import "../../../../Services"
import "../../../../Commons"

Item {
    implicitWidth: Config.bar.height
    implicitHeight: Config.bar.height

    MIconButton {
        anchors.fill: parent
        iconName: "view-grid-symbolic"
        key: "bar.controlPanel"
        checked: Notifications.panelOpen
        onClicked: Notifications.toggle()
    }
}
