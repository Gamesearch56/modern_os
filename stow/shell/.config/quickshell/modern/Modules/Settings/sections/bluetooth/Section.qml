import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

Item {
    id: root

    property var dialogDevice: null
    readonly property bool _online: {
        void root.dialogDevice?.connected;
        void BluetoothAudio.nodeSig;
        return BluetoothAudio.linked(root.dialogDevice);
    }
    readonly property bool _paired: {
        void BluetoothLink.savedGen;
        void root.dialogDevice?.paired;
        void root.dialogDevice?.bonded;
        void root.dialogDevice?.trusted;
        return Bluetooth.isRemembered(root.dialogDevice);
    }
    readonly property string _addr: root.dialogDevice ? String(root.dialogDevice.address || "") : ""
    readonly property bool _busy: BluetoothLink.busy && BluetoothLink.pendingAddress === root._addr
    readonly property bool _failed: BluetoothLink.errorKey.length > 0 && BluetoothLink.errorAddress === root._addr

    implicitHeight: col.implicitHeight

    Component.onCompleted: {
        if (Bluetooth.powered)
            Bluetooth.refresh();
    }
    Component.onDestruction: Bluetooth.setDiscovering(false)

    Connections {
        target: BluetoothLink
        function onSettled(ok, address) {
            if (!ok || !root.dialogDevice || address !== root._addr)
                return;
            root.dialogDevice = null;
        }
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: Tokens.spacing.lg

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.xs
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.md
                MText {
                    key: "settings.fields.bluetoothPower"
                    styleName: "bodyMedium"
                    color: Colors.color.onSurfaceVariant
                    Layout.fillWidth: true
                }
                MSwitch {
                    enabled: Bluetooth.adapterReady
                    checked: Bluetooth.powered
                    onToggled: (v) => Bluetooth.setPowered(v)
                }
            }
            MHint {
                key: Bluetooth.adapterReady ? "settings.hints.bluetooth" : "settings.hints.bluetoothBlocked"
                Layout.fillWidth: true
            }
        }

        ColumnLayout {
            visible: Bluetooth.powered
            Layout.fillWidth: true
            spacing: Tokens.spacing.lg

            MSectionHeader {
                key: "settings.bluetooth.connected"
                topMargin: Tokens.spacing.xl
            }
            DeviceList {
                Layout.fillWidth: true
                devices: Bluetooth.connectedDevices
                emptyKey: "settings.bluetooth.emptyConnected"
                emptyIcon: "bluetooth-disabled"
                onDeviceClicked: (d) => root.dialogDevice = d
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.xl
                spacing: Tokens.spacing.md
                MText {
                    key: "settings.bluetooth.available"
                    styleName: "titleSmall"
                    color: Colors.color.onSurfaceVariant
                    Layout.fillWidth: true
                }
                MIconButton {
                    iconName: "view-refresh"
                    key: "settings.refresh"
                    iconSize: Tokens.icon.sm
                    busy: Bluetooth.refreshing
                    enabled: Bluetooth.powered && !Bluetooth.refreshing
                    onClicked: Bluetooth.refresh()
                }
            }
            DeviceList {
                Layout.fillWidth: true
                devices: Bluetooth.availableDevices
                emptyKey: "settings.bluetooth.emptyAvailable"
                scanningKey: "settings.bluetooth.searching"
                scanning: Bluetooth.refreshing
                onDeviceClicked: (d) => root.dialogDevice = d
            }
        }
    }

    MDialog {
        parent: Window.window ? Window.window.contentItem : root
        anchors.fill: parent
        open: root.dialogDevice !== null
        titleValue: Bluetooth.deviceLabel(root.dialogDevice)
        bodyKey: root._online ? "settings.bluetooth.disconnectBody"
            : (root._paired && BluetoothLink.bondLost(root.dialogDevice)) ? "settings.bluetooth.repairBody" : "settings.bluetooth.connectBody"
        confirmKey: root._busy ? "settings.bluetooth.connecting" : root._online ? "settings.bluetooth.disconnect" : "settings.bluetooth.connect"
        confirmEnabled: !root._busy
        cancelKey: "powerMenu.cancel"
        destructiveKey: root._paired ? "settings.bluetooth.forget" : ""
        onConfirmed: {
            if (root._online) {
                Bluetooth.disconnectDevice(root.dialogDevice);
                root.dialogDevice = null;
                return;
            }
            Bluetooth.connectDevice(root.dialogDevice);
        }

        MText {
            visible: root._failed
            key: BluetoothLink.errorKey
            styleName: "bodySmall"
            color: Colors.color.error
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
        onCancelled: root.dialogDevice = null
        onDestructiveClicked: {
            Bluetooth.forgetDevice(root.dialogDevice);
            root.dialogDevice = null;
        }
    }
}
