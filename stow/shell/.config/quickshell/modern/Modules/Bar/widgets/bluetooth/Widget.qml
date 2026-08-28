import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

RowLayout {
    spacing: Tokens.spacing.xs

    MIcon {
        name: Bluetooth.powered ? "bluetooth-active" : "bluetooth-disabled"
        size: Tokens.spacing.lg
    }

    MText {
        value: Bluetooth.powered ? I18n.t("bluetooth.connected", { count: Bluetooth.connectedCount }) : I18n.t("bluetooth.off")
        styleName: "labelLarge"
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Settings.openAt("network", "bluetooth")
    }
}
