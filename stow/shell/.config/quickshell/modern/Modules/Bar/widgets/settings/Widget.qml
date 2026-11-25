import QtQuick
import "../../../../Widgets"
import "../../../../Services"
import "../../../../Commons"

Item {
    implicitWidth: BarLayout.height
    implicitHeight: BarLayout.height

    MIconButton {
        tabFocus: false
        anchors.fill: parent
        iconName: "view-grid-symbolic"
        key: "bar.controlPanel"
        checked: Notifications.panelOpen
        onClicked: Notifications.toggle()
    }
}
