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
        iconName: "system-shutdown-symbolic"
        key: "bar.power"
        checked: PowerMenu.open
        onClicked: PowerMenu.toggle()
    }
}
