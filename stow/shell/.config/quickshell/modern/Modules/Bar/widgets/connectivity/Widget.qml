import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Services"
import "../../"

Item {
    id: root
    implicitWidth: BarLayout.vertical ? BarLayout.height : row.implicitWidth
    implicitHeight: BarLayout.vertical ? row.implicitHeight : BarLayout.height

    readonly property bool _wide: !BarLayout.vertical
    readonly property string _wifiIcon: Network.linkKind === "wifi" ? "network-wireless-symbolic" : (Network.linkKind === "ethernet" ? "network-wired-symbolic" : "network-offline-symbolic")
    readonly property string _ssid: Network.ssid
    readonly property string _btName: Bluetooth.deviceLabel(Bluetooth.connectedDevices[0])

    function _openNet() {
        if (Settings.open && Settings.sectionId === "network")
            Settings.close();
        else
            Settings.openAt("network", "");
    }

    function _openBt() {
        if (Settings.open && Settings.sectionId === "bluetooth")
            Settings.close();
        else
            Settings.openAt("bluetooth", "");
    }

    GridLayout {
        id: row
        anchors.centerIn: parent
        columns: BarLayout.vertical ? 1 : 2
        columnSpacing: 0
        rowSpacing: 0

        BarIconLabel {
            iconName: root._wifiIcon
            key: "bar.network"
            label: root._ssid
            showLabel: root._wide
            checked: Settings.open && Settings.sectionId === "network"
            onClicked: root._openNet()
        }

        BarIconLabel {
            iconName: Bluetooth.powered ? "bluetooth-active-symbolic" : "bluetooth-disabled-symbolic"
            key: "bar.bluetooth"
            label: root._btName
            showLabel: root._wide
            checked: Settings.open && Settings.sectionId === "bluetooth"
            onClicked: root._openBt()
        }
    }
}
