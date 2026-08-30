import QtQuick
import "../../../../Widgets"
import "../../../../Services"
import "../../../../Commons"

Item {
    implicitWidth: Config.bar.height
    implicitHeight: Config.bar.height

    MIconButton {
        tabFocus: false
        anchors.fill: parent
        iconName: "system-shutdown-symbolic"
        key: "bar.power"
        checked: PowerMenu.open
        onClicked: PowerMenu.toggle()
    }
}
