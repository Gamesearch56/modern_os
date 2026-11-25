import QtQuick
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

Item {
    implicitWidth: Tokens.spacing.xxl
    implicitHeight: Tokens.spacing.xxl

    MIconButton {
        tabFocus: false
        anchors.centerIn: parent
        iconName: Network.linkKind === "wifi" ? "network-wireless-symbolic" : (Network.linkKind === "ethernet" ? "network-wired-symbolic" : "network-offline-symbolic")
        key: "bar.network"
        onClicked: Settings.openAt("network", "")
    }
}
