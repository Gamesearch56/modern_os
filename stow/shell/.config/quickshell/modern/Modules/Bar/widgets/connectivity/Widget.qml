import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

Item {
    id: root
    implicitWidth: BarLayout.vertical ? Config.bar.height : row.implicitWidth
    implicitHeight: BarLayout.vertical ? row.implicitHeight : Config.bar.height

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

    GridLayout {
        id: row
        anchors.fill: parent
        columns: BarLayout.vertical ? 1 : 8
        rowSpacing: 0
        columnSpacing: 0

        MIconButton {
            tabFocus: false
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
            visible: !BarLayout.vertical && root._ssid.length > 0
            value: root._ssid
            styleName: "labelSmall"
            elide: Text.ElideRight
            Layout.maximumWidth: Tokens.spacing.xxl * 4
        }

        MIconButton {
            tabFocus: false
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
            visible: !BarLayout.vertical && root._btName.length > 0
            value: root._btName
            styleName: "labelSmall"
            elide: Text.ElideRight
            Layout.maximumWidth: Tokens.spacing.xxl * 4
        }
    }
}
