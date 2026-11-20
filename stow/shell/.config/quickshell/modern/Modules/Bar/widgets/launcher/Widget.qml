import QtQuick
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

Item {
    implicitWidth: BarLayout.height
    implicitHeight: BarLayout.height

    MIconButton {
        tabFocus: false
        anchors.fill: parent
        iconName: "view-app-grid-symbolic"
        key: "bar.launcher"
        checked: Launcher.open
        onClicked: Launcher.toggle()
    }
}
