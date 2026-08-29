import QtQuick
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

Item {
    implicitWidth: Config.bar.height
    implicitHeight: Config.bar.height

    MIconButton {
        anchors.fill: parent
        iconName: "view-app-grid-symbolic"
        key: "bar.launcher"
        checked: Launcher.open
        onClicked: Launcher.toggle()
    }
}
