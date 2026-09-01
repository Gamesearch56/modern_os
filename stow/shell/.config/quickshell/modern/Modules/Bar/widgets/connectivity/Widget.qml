import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "../../"

Item {
    id: root
    implicitWidth: BarLayout.vertical ? Config.bar.height : row.implicitWidth
    implicitHeight: BarLayout.vertical ? row.implicitHeight : Config.bar.height

    readonly property bool _wide: !BarLayout.vertical
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
        columns: BarLayout.vertical ? 1 : 3
        columnSpacing: 0
        rowSpacing: 0

        MIconButton {
            tabFocus: false
            iconName: root._wifiIcon
            key: "bar.network"
            size: Config.bar.height
            checked: Settings.open && Settings.sectionId === "network"
            onClicked: root._openNet()
        }

        MText {
            visible: root._wide && root._ssid.length > 0
            value: root._ssid
            styleName: "labelSmall"
            elide: Text.ElideRight
            Layout.preferredWidth: visible ? implicitWidth : 0
            Layout.preferredHeight: visible ? implicitHeight : 0
            Layout.maximumWidth: Tokens.spacing.xxl * 6
            Layout.rightMargin: visible ? Tokens.spacing.xs : 0
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
