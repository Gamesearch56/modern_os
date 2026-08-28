import QtQuick
import "../../../../Widgets"
import "../../../../Services"

MIconButton {
    iconName: "view-app-grid-symbolic"
    key: "bar.launcher"
    onClicked: Launcher.toggle()
}
