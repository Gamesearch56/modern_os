// BlueZ via Quickshell.Bluetooth. Adapter power, device list, connect
// and pair. The bluetooth widget never calls bluetoothctl. When
// audio.autoSwitchBluetooth is on, paired audio devices are trusted
// and connected as they appear — mice and keyboards are left alone.
pragma Singleton

import Quickshell
import Quickshell.Bluetooth
import QtQuick
import "../Commons"

Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devices: Bluetooth.devices
    readonly property bool powered: root.adapter?.enabled ?? false
    readonly property bool discovering: root.adapter?.discovering ?? false
    readonly property bool autoAudio: (Config.audio.autoSwitchBluetooth || "on") !== "off"
    readonly property int connectedCount: {
        let n = 0;
        const list = root.devices?.values ?? [];
        for (let i = 0; i < list.length; i++) {
            if (list[i].connected)
                n++;
        }
        return n;
    }

    readonly property string _devSig: {
        const list = root.devices?.values ?? [];
        let s = "";
        for (let i = 0; i < list.length; i++) {
            const d = list[i];
            s += String(d.address || "") + ":" + (d.paired ? "1" : "0") + ":" + (d.connected ? "1" : "0") + ",";
        }
        return s;
    }

    property var _connectTried: ({})

    on_DevSigChanged: root._syncAutoAudio()
    onAutoAudioChanged: {
        if (root.autoAudio)
            root._connectTried = ({});
        root._syncAutoAudio();
    }
    onPoweredChanged: {
        if (root.powered)
            root._connectTried = ({});
        root._syncAutoAudio();
    }

    Component.onCompleted: Qt.callLater(root._syncAutoAudio)

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

    function isAudioDevice(device: var): bool {
        if (!device)
            return false;
        const icon = String(device.icon || "").toLowerCase();
        return icon.indexOf("audio") !== -1 || icon.indexOf("headset") !== -1
            || icon.indexOf("headphone") !== -1 || icon.indexOf("speaker") !== -1;
    }

    function _syncAutoAudio() {
        if (!root.autoAudio || !root.powered)
            return;
        const list = root.devices?.values ?? [];
        const present = {};
        const tried = Object.assign({}, root._connectTried);
        for (let i = 0; i < list.length; i++) {
            const d = list[i];
            const addr = String(d.address || "");
            if (!addr.length)
                continue;
            present[addr] = true;
            if (!d.paired || d.blocked || !root.isAudioDevice(d))
                continue;
            if (!d.trusted)
                d.trusted = true;
            if (d.connected || tried[addr])
                continue;
            tried[addr] = true;
            d.connect();
        }
        const next = {};
        for (const k in tried) {
            if (present[k])
                next[k] = true;
        }
        root._connectTried = next;
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
