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
        model: Bluetooth.connectedDevices
        MListItem {
            required property var modelData
            Layout.fillWidth: true
            titleValue: modelData.name || ""
            subtitleValue: modelData.address || ""
            onClicked: root.dialogDevice = modelData
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
        model: Bluetooth.availableDevices
        MListItem {
            required property var modelData
            Layout.fillWidth: true
            titleValue: modelData.name || ""
            onClicked: root.dialogDevice = modelData
        }
    }

    MDialog {
        anchors.fill: parent
        open: root.dialogDevice !== null
        titleValue: root.dialogDevice ? (root.dialogDevice.name || "") : ""
        confirmKey: root.dialogDevice && root.dialogDevice.connected ? "settings.bluetooth.forget" : "settings.bluetooth.connect"
        destructive: !!(root.dialogDevice && root.dialogDevice.connected)
        onConfirmed: {
            const d = root.dialogDevice;
            if (!d) {
                root.dialogDevice = null;
                return;
            }
            if (d.connected)
                Bluetooth.forgetDevice(d);
            else
                Bluetooth.connectDevice(d);
            root.dialogDevice = null;
        }
        onCancelled: root.dialogDevice = null
    }
}
