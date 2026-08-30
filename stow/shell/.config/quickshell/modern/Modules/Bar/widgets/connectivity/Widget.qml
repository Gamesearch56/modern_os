import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: Config.bar.height

    readonly property string _wifiIcon: Network.connected ? (Network.ssid.length > 0 ? "network-wireless-symbolic" : "network-wired-symbolic") : "network-offline-symbolic"
    readonly property string _ssid: Network.ssid
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
        anchors.fill: parent
        spacing: 0

        MIconButton {
            iconName: root._wifiIcon
            key: "bar.network"
            size: Config.bar.height
            checked: Settings.open && Settings.sectionId === "network"
            onClicked: {
                if (Settings.open && Settings.sectionId === "network")
                    Settings.close();
                else
                    Settings.openAt("network", "");
            }
        }

        MText {
            visible: root._ssid.length > 0
            value: root._ssid
            styleName: "labelSmall"
            elide: Text.ElideRight
            Layout.maximumWidth: Tokens.spacing.xxl * 4
        }

        MIconButton {
            iconName: Bluetooth.powered ? "bluetooth-active-symbolic" : "bluetooth-disabled-symbolic"
            key: "bar.bluetooth"
            size: Config.bar.height
            checked: Settings.open && Settings.sectionId === "bluetooth"
            onClicked: {
                if (Settings.open && Settings.sectionId === "bluetooth")
                    Settings.close();
                else
                    Settings.openAt("bluetooth", "");
            }
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
