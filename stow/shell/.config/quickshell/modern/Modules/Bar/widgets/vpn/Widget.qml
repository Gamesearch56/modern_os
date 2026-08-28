import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

RowLayout {
    spacing: Tokens.spacing.xs

    MIcon { name: "network-vpn"; size: Tokens.spacing.lg }
    MText { key: "vpn.disconnected"; styleName: "labelLarge" }

    MouseArea {
        anchors.fill: parent
        onClicked: Settings.openAt("network", "vpn")
    }
}
