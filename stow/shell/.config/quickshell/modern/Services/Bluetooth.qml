// BlueZ via Quickshell.Bluetooth. Adapter power, device list, connect
// and pair. The bluetooth widget never calls bluetoothctl. When
// audio.autoSwitchBluetooth is on, paired audio devices are trusted
// and connected as they appear — mice and keyboards are left alone.
pragma Singleton

import Quickshell
import Quickshell.Bluetooth as Bluez
import QtQuick
import "../Commons"

Singleton {
    id: root

    readonly property var adapter: Bluez.Bluetooth.defaultAdapter
    readonly property var devices: Bluez.Bluetooth.devices
    readonly property bool powered: root.adapter?.enabled ?? false
    readonly property bool discovering: root.adapter?.discovering ?? false
    readonly property bool adapterReady: !!root.adapter && root.adapter.state !== Bluez.BluetoothAdapterState.Blocked
    readonly property bool autoAudio: (Config.audio.autoSwitchBluetooth || "on") !== "off"
    readonly property int connectedCount: root.connectedDevices.length

    readonly property string _devSig: {
        const list = root._list(root.devices);
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

    function _list(model: var): var {
        if (!model)
            return [];
        if (model.values)
            return model.values;
        return model;
    }

    function setPowered(on: bool) {
        const a = root.adapter;
        if (!a)
            return;
        a.enabled = on;
        a.discovering = on;
    }

    function setDiscovering(on: bool) {
        if (root.adapter)
            root.adapter.discovering = on;
    }

    function refresh() {
        const a = root.adapter;
        if (!a || !root.powered)
            return;
        if (a.discovering) {
            a.discovering = false;
            Qt.callLater(() => {
                if (root.adapter && root.powered)
                    root.adapter.discovering = true;
            });
        } else {
            a.discovering = true;
        }
    }

    function connectDevice(device: var) {
        if (!device)
            return;
        try {
            if (!device.trusted)
                device.trusted = true;
            if (!device.paired && device.pair)
                device.pair();
            if (device.connect)
                device.connect();
        } catch (e) {
            Logger.error("Bluetooth", String(e));
        }
    }

    function disconnectDevice(device: var) {
        if (device && device.disconnect)
            device.disconnect();
    }

    function forgetDevice(device: var) {
        if (!device)
            return;
        try {
            if (device.forget)
                device.forget();
            else if (root.adapter && root.adapter.removeDevice)
                root.adapter.removeDevice(device);
        } catch (e) {
            Logger.error("Bluetooth", String(e));
        }
    }

    function isAudioDevice(device: var): bool {
        if (!device)
            return false;
        const icon = String(device.icon || "").toLowerCase();
        return icon.indexOf("audio") !== -1 || icon.indexOf("headset") !== -1
            || icon.indexOf("headphone") !== -1 || icon.indexOf("speaker") !== -1;
    }

    function deviceLabel(device: var): string {
        if (!device)
            return "";
        return String(device.name || device.deviceName || device.address || "").trim();
    }

    function deviceIcon(device: var): string {
        if (!device)
            return "bluetooth";
        const ic = String(device.icon || "").trim();
        if (ic.length)
            return ic;
        const n = String(device.name || device.deviceName || "").toLowerCase();
        if (n.indexOf("head") !== -1 || n.indexOf("buds") !== -1)
            return "audio-headphones";
        if (n.indexOf("speaker") !== -1)
            return "audio-speakers";
        if (n.indexOf("controller") !== -1 || n.indexOf("gamepad") !== -1)
            return "input-gaming";
        if (n.indexOf("mouse") !== -1)
            return "input-mouse";
        if (n.indexOf("keyboard") !== -1)
            return "input-keyboard";
        if (n.indexOf("phone") !== -1)
            return "phone";
        return "bluetooth";
    }

    function _syncAutoAudio() {
        if (!root.autoAudio || !root.powered)
            return;
        const list = root._list(root.devices);
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

    function _byConnected(want: bool): var {
        const out = [];
        const list = root._list(root.devices);
        for (let i = 0; i < list.length; i++) {
            const d = list[i];
            void d.connected;
            if (!!d.connected === want)
                out.push(d);
        }
        return out;
    }

    readonly property var connectedDevices: { void root._devSig; return root._byConnected(true); }
    readonly property var availableDevices: { void root._devSig; return root._byConnected(false); }
}
