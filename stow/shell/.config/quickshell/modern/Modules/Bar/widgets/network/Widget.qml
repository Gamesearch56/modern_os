import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

RowLayout {
    spacing: Tokens.spacing.xs

    MIcon {
        name: Network.connected ? (Network.wifi?.ssid ? "network-wireless" : "network-wired") : "network-offline"
        size: Tokens.spacing.lg
    }

    MText {
        value: Network.connected ? (Network.primaryName === "ethernet" ? I18n.t("network.ethernet") : Network.primaryName) : I18n.t("network.disconnected")
        styleName: "labelLarge"
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Settings.openAt("network", "")
    }
}
