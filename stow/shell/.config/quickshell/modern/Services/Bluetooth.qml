// BlueZ via Quickshell.Bluetooth. Adapter power, device list, connect
// and pair. The bluetooth widget never calls bluetoothctl.
pragma Singleton

import Quickshell
import Quickshell.Bluetooth
import QtQuick

Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devices: Bluetooth.devices
    readonly property bool powered: root.adapter?.enabled ?? false
    readonly property bool discovering: root.adapter?.discovering ?? false
    readonly property int connectedCount: {
        let n = 0;
        const list = root.devices?.values ?? [];
        for (let i = 0; i < list.length; i++) {
            if (list[i].connected)
                n++;
        }
        return n;
    }

    function setPowered(on: bool) {
        if (root.adapter)
            root.adapter.enabled = on;
    }

    function setDiscovering(on: bool) {
        if (root.adapter)
            root.adapter.discovering = on;
    }

    function connectDevice(device: var) {
        if (device)
            device.connect();
    }

    function disconnectDevice(device: var) {
        if (device)
            device.disconnect();
    }

    function pairDevice(device: var) {
        if (device)
            device.pair();
    }

    function forgetDevice(device: var) {
        if (!device)
            return;
        if (device.forget)
            device.forget();
        else if (root.adapter?.removeDevice)
            root.adapter.removeDevice(device);
    }

    readonly property var connectedDevices: {
        const out = [];
        const list = root.devices?.values ?? [];
        for (let i = 0; i < list.length; i++) {
            if (list[i].connected)
                out.push(list[i]);
        }
        return out;
    }

    readonly property var availableDevices: {
        const out = [];
        const list = root.devices?.values ?? [];
        for (let i = 0; i < list.length; i++) {
            if (!list[i].connected)
                out.push(list[i]);
        }
        return out;
    }
}
