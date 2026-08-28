import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

Item {
    id: root
    implicitWidth: row.implicitWidth + Tokens.spacing.sm
    implicitHeight: Tokens.spacing.xl + Tokens.spacing.xs

    readonly property string _wifiIcon: Network.connected ? (Network.wifi?.ssid ? "network-wireless" : "network-wired") : "network-offline"
    readonly property string _btName: {
        const list = Bluetooth.devices?.values ?? [];
        for (let i = 0; i < list.length; i++) {
            if (list[i].connected)
                return list[i].name || "";
        }
        return "";
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.spacing.xs

        MIconButton {
            iconName: root._wifiIcon
            key: "bar.network"
            onClicked: Settings.openAt("network", "")
        }

        MIconButton {
            iconName: Bluetooth.powered ? "bluetooth-active" : "bluetooth-disabled"
            key: "bar.bluetooth"
            onClicked: Settings.openAt("bluetooth", "")
        }

        MText {
            visible: root._btName.length > 0
            value: root._btName
            styleName: "labelSmall"
            elide: Text.ElideRight
            Layout.maximumWidth: Tokens.spacing.xxl * 4
        }
    }
}
