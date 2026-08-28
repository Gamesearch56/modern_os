import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    spacing: Tokens.spacing.md

    MSectionHeader { key: "bar.network" }
    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.wifi"
        MSwitch {
            checked: Network.wifiEnabled
            onToggled: (v) => Network.setWifiEnabled(v)
        }
    }
    Repeater {
        model: Network.networks
        MListItem {
            required property var modelData
            Layout.fillWidth: true
            titleValue: modelData.ssid || modelData.name || ""
            selected: !!modelData.active
            onClicked: Network.connect(modelData, "")
        }
    }

    MSectionHeader { key: "bar.bluetooth" }
    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.bluetoothPower"
        MSwitch {
            checked: Bluetooth.powered
            onToggled: (v) => Bluetooth.setPowered(v)
        }
    }
    Repeater {
        model: Bluetooth.devices?.values ?? []
        MListItem {
            required property var modelData
            Layout.fillWidth: true
            titleValue: modelData.name || ""
            selected: !!modelData.connected
            onClicked: modelData.connected ? Bluetooth.disconnectDevice(modelData) : Bluetooth.connectDevice(modelData)
        }
    }
}
