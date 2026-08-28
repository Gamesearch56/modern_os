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
        iconName: Network.connected ? (Network.wifi?.ssid ? "network-wireless" : "network-wired") : "network-offline"
        key: "bar.network"
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
