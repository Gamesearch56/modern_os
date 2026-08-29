import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    id: root
    spacing: Tokens.spacing.md

    property var dialogDevice: null

    Component.onCompleted: Bluetooth.setDiscovering(true)
    Component.onDestruction: Bluetooth.setDiscovering(false)

    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.bluetoothPower"
        MSwitch {
            checked: Bluetooth.powered
            onToggled: (v) => Bluetooth.setPowered(v)
        }
    }

    MSectionHeader { key: "settings.bluetooth.connected" }
    Repeater {
        model: Bluetooth.connectedDevices.length
        MListItem {
            required property int index
            readonly property var dev: Bluetooth.connectedDevices[index]
            Layout.fillWidth: true
            titleValue: (dev && dev.name) ? dev.name : ""
            subtitleValue: (dev && dev.address) ? dev.address : ""
            onClicked: root.dialogDevice = dev
        }
    }
    MEmptyState {
        visible: Bluetooth.connectedDevices.length === 0
        Layout.fillWidth: true
        Layout.preferredHeight: Tokens.spacing.xxl * 3
        iconName: "bluetooth-disabled"
        titleKey: "settings.bluetooth.emptyConnected"
    }

    MSectionHeader { key: "settings.bluetooth.available" }
    Repeater {
        model: Bluetooth.availableDevices.length
        MListItem {
            required property int index
            readonly property var dev: Bluetooth.availableDevices[index]
            Layout.fillWidth: true
            titleValue: (dev && dev.name) ? dev.name : ""
            onClicked: root.dialogDevice = dev
        }
    }
}
