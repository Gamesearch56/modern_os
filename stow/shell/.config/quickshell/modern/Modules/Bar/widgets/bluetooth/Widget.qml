import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

Item {
    id: root
    implicitWidth: Tokens.spacing.xxl
    implicitHeight: Tokens.spacing.xxl

    MIconButton {
        anchors.centerIn: parent
        iconName: Bluetooth.powered ? "bluetooth-active" : "bluetooth-disabled"
        key: "bar.bluetooth"
        onClicked: popup.open = !popup.open
    }

    MPopup {
        id: popup
        open: false
        width: Tokens.spacing.xxl * 10
        height: Tokens.spacing.xxl * 10
        y: root.height + Tokens.spacing.sm
        x: root.width - width

        Panel {}
    }
}
