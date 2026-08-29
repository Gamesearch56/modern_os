import QtQuick
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

Item {
    implicitWidth: Tokens.spacing.xxl
    implicitHeight: Tokens.spacing.xxl

    MIconButton {
        anchors.centerIn: parent
        iconName: Network.connected ? (Network.wifi?.ssid ? "network-wireless-symbolic" : "network-wired-symbolic") : "network-offline-symbolic"
        key: "bar.network"
        onClicked: Settings.openAt("network", "")
    }
}
