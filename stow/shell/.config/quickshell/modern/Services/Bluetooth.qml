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
            s += String(d.address || "") + ":" + (d.paired ? "1" : "0") + ":"
                + (d.bonded ? "1" : "0") + ":" + (d.connected ? "1" : "0") + ":"
                + String(d.name || d.deviceName || "") + ",";
        }
        return s;
    }

    property var _connectTried: ({})
    property var _seenAt: ({})
    property int _seenSeq: 0
    property bool refreshing: false
    property bool _uiReady: false

    Timer {
        id: refreshBusy
        interval: Math.max(Motion.bluetoothScanMs, 1)
        onTriggered: root.refreshing = false
    }

    Timer {
        id: refreshKick
        interval: Math.max(Motion.shortMs, 1)
        onTriggered: {
            if (root.adapter && root.powered)
                root.adapter.discovering = true;
        }
    }

    on_DevSigChanged: {
        root._stampSeen();
        if (root._uiReady)
            root._syncAutoAudio();
    }
    onAutoAudioChanged: {
        if (root.autoAudio)
            root._connectTried = ({});
        if (root._uiReady)
            root._syncAutoAudio();
    }
    onPoweredChanged: {
        if (root.powered)
            root._connectTried = ({});
        if (root._uiReady)
            root._syncAutoAudio();
    }

    Timer {
        interval: Math.max(Motion.extraLongMs, 1)
        running: true
        repeat: false
        onTriggered: {
            root._uiReady = true;
            root._syncAutoAudio();
        }
    }

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
        if (!a || !root.powered || root.refreshing)
            return;
        root.refreshing = true;
        refreshBusy.restart();
        a.discovering = false;
        refreshKick.restart();
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

    // BlueZ uses the MAC as Alias when a BLE advertiser has no GAP name.
    function isNamed(device: var): bool {
        const label = String(device?.name || device?.deviceName || "").trim();
        if (!label.length)
            return false;
        return !/^([0-9A-F]{2}[:-]){5}[0-9A-F]{2}$/i.test(label);
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
            Qt.callLater(() => root.connectDevice(d));
        }
        const next = {};
        for (const k in tried) {
            if (present[k])
                next[k] = true;
        }
        root._connectTried = next;
    }

    function _stampSeen() {
        const list = root._list(root.devices);
        const present = {};
        const next = Object.assign({}, root._seenAt);
        let seq = root._seenSeq;
        let changed = false;
        for (let i = 0; i < list.length; i++) {
            const d = list[i];
            const addr = String(d?.address || "");
            if (!addr.length)
                continue;
            if (!(d.connected || d.paired || d.bonded || d.trusted || root.isNamed(d)))
                continue;
            present[addr] = true;
            if (next[addr] === undefined) {
                seq += 1;
                next[addr] = seq;
                changed = true;
            }
        }
        if (list.length > 0) {
            for (const k in next) {
                if (!present[k]) {
                    delete next[k];
                    changed = true;
                }
            }
        }
        if (!changed)
            return;
        root._seenAt = next;
        root._seenSeq = seq;
    }

    function _byConnected(want: bool): var {
        const out = [];
        const list = root._list(root.devices);
        for (let i = 0; i < list.length; i++) {
            const d = list[i];
            void d.connected;
            void d.paired;
            void d.bonded;
            void d.name;
            void d.deviceName;
            if (!!d.connected !== want)
                continue;
            if (!want && !(d.paired || d.bonded || d.trusted || root.isNamed(d)))
                continue;
            out.push(d);
        }
        if (!want) {
            const seen = root._seenAt;
            out.sort((a, b) => {
                const ak = !!(a && (a.paired || a.bonded));
                const bk = !!(b && (b.paired || b.bonded));
                if (ak !== bk)
                    return ak ? -1 : 1;
                return (seen[String(b?.address || "")] || 0) - (seen[String(a?.address || "")] || 0);
            });
        }
        return out;
    }

    readonly property var connectedDevices: { void root._devSig; return root._byConnected(true); }
    readonly property var availableDevices: {
        void root._devSig;
        void root._seenSeq;
        return root._byConnected(false);
    }
}
