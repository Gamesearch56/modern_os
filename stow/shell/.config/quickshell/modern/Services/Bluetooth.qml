// BlueZ via Quickshell.Bluetooth. Adapter power and the device list.
// Connect, pair, and the saved-device flag live in BluetoothLink.
// Discovery is a short search, not the powered state: a scan makes
// both hosts page a multipoint headset. Trust is applied when that
// search is idle, so a saved headset can come back without a new bond.
// Mice and keyboards are left alone.
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
    // Only an explicit "on" connects. Stray values (e.g. leftover "ask")
    // must not auto-connect multipoint buds and steal the phone's A2DP.
    readonly property bool autoAudio: (Config.audio.autoSwitchBluetooth || "on") === "on"
    readonly property int connectedCount: root.connectedDevices.length

    readonly property string _devSig: {
        const list = root._list(root.devices);
        let s = "";
        for (let i = 0; i < list.length; i++) {
            const d = list[i];
            s += String(d.address || "") + ":" + (d.paired ? "1" : "0") + ":"
                + (d.bonded ? "1" : "0") + ":" + (d.trusted ? "1" : "0") + ":"
                + (d.connected ? "1" : "0") + ":" + (d.pairing ? "1" : "0") + ":"
                + String(d.state) + ":" + String(d.name || d.deviceName || "") + ",";
        }
        return s;
    }

    property var _seenAt: ({})
    property int _seenSeq: 0
    property bool refreshing: false
    property bool _uiReady: false

    Timer {
        id: refreshBusy
        interval: Math.max(Motion.bluetoothScanMs, 1)
        onTriggered: root.setDiscovering(false)
    }

    Timer {
        id: refreshKick
        interval: Math.max(Motion.shortMs, 1)
        onTriggered: {
            if (root.adapter && root.powered && !BluetoothLink.busy && !BluetoothClassic.scanning)
                root.adapter.discovering = true;
        }
    }

    // Deferred: trusting a device inside this handler changes _devSig
    // while it is still being evaluated (a binding loop).
    on_DevSigChanged: Qt.callLater(root._onDevices)

    function _onDevices() {
        root._stampSeen();
        BluetoothLink.note();
        BluetoothLink.settle();
        if (root._uiReady)
            root._syncAutoAudio();
    }
    onAutoAudioChanged: if (root._uiReady) root._syncAutoAudio()
    onPoweredChanged: if (root._uiReady) root._syncAutoAudio()

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
        if (!on)
            a.discovering = false;
    }

    // Stopping also cancels a pending refresh, or its kick would start
    // the search again under a classic scan that is about to pair. A Stop
    // with no search running only makes BlueZ answer with an error.
    function setDiscovering(on: bool) {
        if (root.adapter && (on || root.adapter.discovering || root.refreshing))
            root.adapter.discovering = on;
        if (!on) {
            refreshKick.stop();
            refreshBusy.stop();
            root.refreshing = false;
        }
        if (!on && root._uiReady)
            root._syncAutoAudio();
    }

    function refresh() {
        const a = root.adapter;
        if (!a || !root.powered || root.refreshing || BluetoothLink.busy || BluetoothClassic.scanning)
            return;
        root.refreshing = true;
        refreshBusy.restart();
        a.discovering = false;
        refreshKick.restart();
    }

    function connectDevice(device: var) { BluetoothLink.connect(device); }
    function disconnectDevice(device: var) { BluetoothLink.disconnect(device); }
    function forgetDevice(device: var) { BluetoothLink.forget(device); }
    function isRemembered(device: var): bool { return BluetoothLink.isRemembered(device); }

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
        if (!root.autoAudio || !root.powered || root.discovering || BluetoothLink.busy)
            return;
        const list = root._list(root.devices);
        for (let i = 0; i < list.length; i++) {
            const d = list[i];
            if (!d.paired || d.blocked || !root.isAudioDevice(d))
                continue;
            if (!d.trusted)
                d.trusted = true;
        }
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
            if (BluetoothAudio.linked(d) !== want)
                continue;
            if (!want && !d.connected && BluetoothLink.shadowed(d))
                continue;
            if (!want && !root.isRemembered(d) && !root.isNamed(d))
                continue;
            out.push(d);
        }
        const seen = root._seenAt;
        out.sort((a, b) => root._order(a, b, seen));
        return out;
    }

    // Connected, then saved devices, then everything else, strongest
    // signal first. A new scan must not lift an unknown device above one
    // this machine remembers.
    function _order(a: var, b: var, seen: var): int {
        const ar = BluetoothAudio.linked(a) ? 0 : 1;
        const br = BluetoothAudio.linked(b) ? 0 : 1;
        if (ar !== br)
            return ar - br;
        const s = BluetoothSignal.compare(a, b);
        if (s !== 0)
            return s;
        return (seen[String(b?.address || "")] || 0) - (seen[String(a?.address || "")] || 0);
    }

    readonly property var connectedDevices: {
        void root._devSig;
        void BluetoothAudio.nodeSig;
        return root._byConnected(true);
    }
    readonly property var availableDevices: {
        void root._devSig;
        void root._seenSeq;
        void BluetoothSignal.rev;
        void BluetoothLink.savedGen;
        void BluetoothAudio.nodeSig;
        return root._byConnected(false);
    }
    readonly property var sortedDevices: {
        void root._devSig;
        void root._seenSeq;
        void BluetoothSignal.rev;
        void BluetoothLink.savedGen;
        void BluetoothAudio.nodeSig;
        const list = root._list(root.devices).slice();
        const seen = root._seenAt;
        list.sort((a, b) => root._order(a, b, seen));
        return list;
    }
}
