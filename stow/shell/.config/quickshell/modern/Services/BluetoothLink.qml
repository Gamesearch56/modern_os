pragma Singleton

import Quickshell
import Quickshell.Bluetooth as Bluez
import QtQuick
import "../Commons"

// One connect or pair at a time, and the result of it.
// A bonded headset is never paired again: a second bond drops the other
// host. Inquiry is stopped first so the page is not cancelled by a scan.
// Quickshell reports no BlueZ error string; a return to Disconnected
// after Connecting, or the connect timeout, is the failure.

Singleton {
    id: root

    signal settled(bool ok, string address)

    property string errorKey: ""
    property string errorAddress: ""
    property string pendingAddress: ""
    readonly property bool busy: root.pendingAddress.length > 0
    property int savedGen: 0

    property var _saved: ({})
    property bool _saw: false
    property bool _pairing: false
    property string _failKey: "settings.bluetooth.connectFailed"

    Timer {
        id: attempt
        interval: Math.max(Motion.bluetoothConnectMs, 1)
        onTriggered: root._fail()
    }

    function isRemembered(device: var): bool {
        void root.savedGen;
        if (!device)
            return false;
        const addr = String(device.address || "");
        return !!(device.paired || device.bonded || device.trusted || (addr.length && root._saved[addr]));
    }

    // Saved here, but BlueZ holds no key: the headset was reset or paired
    // fresh elsewhere, and the next key-missing refusal deleted the bond.
    // Connect cannot work; only a new pair can.
    function bondLost(device: var): bool {
        return root.isRemembered(device) && !device.paired && !device.bonded;
    }

    // The LE advert of a headset we already saved. Connecting that copy
    // starts a new pair and the saved row loses its bond flag.
    function shadowed(device: var): bool {
        if (!device || device.connected || root.isRemembered(device))
            return false;
        const name = Bluetooth.deviceLabel(device).toLowerCase();
        if (!name.length)
            return false;
        const list = Bluetooth._list(Bluetooth.devices);
        for (let i = 0; i < list.length; i++) {
            const other = list[i];
            if (other === device || !root.isRemembered(other))
                continue;
            if (Bluetooth.deviceLabel(other).toLowerCase() === name)
                return true;
        }
        return false;
    }

    function note() {
        const list = Bluetooth._list(Bluetooth.devices);
        const next = Object.assign({}, root._saved);
        let changed = false;
        for (let i = 0; i < list.length; i++) {
            const d = list[i];
            const addr = String(d && d.address || "");
            if (!addr.length || next[addr])
                continue;
            if (d.paired || d.bonded || d.trusted) {
                next[addr] = true;
                changed = true;
            }
        }
        if (!changed)
            return;
        root._saved = next;
        root.savedGen += 1;
    }

    function _device(addr: string): var {
        const list = Bluetooth._list(Bluetooth.devices);
        for (let i = 0; i < list.length; i++)
            if (String(list[i] && list[i].address || "") === addr)
                return list[i];
        return null;
    }

    function _bond(device: var): var {
        if (!device || root.isRemembered(device))
            return device;
        const name = Bluetooth.deviceLabel(device).toLowerCase();
        if (!name.length)
            return device;
        const list = Bluetooth._list(Bluetooth.devices);
        for (let i = 0; i < list.length; i++) {
            const other = list[i];
            if (other !== device && root.isRemembered(other)
                    && Bluetooth.deviceLabel(other).toLowerCase() === name)
                return other;
        }
        return device;
    }

    function _clear() {
        root.pendingAddress = "";
        root._saw = false;
        root._pairing = false;
        attempt.stop();
        BluetoothClassic.cancel();
    }

    function _ok() {
        const addr = root.pendingAddress;
        root._clear();
        root.errorKey = "";
        root.errorAddress = "";
        Logger.info("Bluetooth", "connected");
        root.settled(true, addr);
    }

    function _fail() {
        const addr = root.pendingAddress;
        if (!addr.length)
            return;
        let key = root._failKey;
        root._clear();
        // A link the headset holds without audio only blocks its slot
        // for the computer or phone that is playing.
        const dev = root._device(addr);
        // noAudio needs a link that is still up; a dropped link is a plain failure.
        if (key === "settings.bluetooth.noAudio" && dev && !dev.connected)
            key = root.bondLost(dev) ? "settings.bluetooth.bondLost" : "settings.bluetooth.connectFailed";
        // State at failure tells a report which step stopped. A warning,
        // not an error: errors toast raw text, and the result toasts already.
        Logger.warn("Bluetooth", key + (dev ? " paired=" + !!dev.paired + " bonded=" + !!dev.bonded
            + " trusted=" + !!dev.trusted + " link=" + !!dev.connected + " audio=" + BluetoothAudio.audioUp(dev) : ""));
        const d = key === "settings.bluetooth.noAudio" ? dev : null;
        if (d && d.connected && !BluetoothAudio.audioUp(d))
            d.disconnect();
        root.errorKey = key;
        root.errorAddress = addr;
        root.settled(false, addr);
    }

    function settle() {
        if (!root.pendingAddress.length)
            return;
        const d = root._device(root.pendingAddress);
        if (!d)
            return;
        // Pairing holds a link before the bond exists. Counting that link
        // as done skipped trust, and an untrusted headset is refused when
        // it connects back on its own.
        if (root._pairing && (d.paired || d.bonded)) {
            root._pairing = false;
            root._failKey = "settings.bluetooth.connectFailed";
            root._saw = false;
            try {
                if (!d.trusted)
                    d.trusted = true;
                // Pairing already brought the link up. Connect on that
                // link is what BlueZ logs as "already connected".
                if (d.connected)
                    BluetoothAudio.ask(d);
                else if (d.connect)
                    d.connect();
                attempt.interval = Math.max(Motion.bluetoothConnectMs, 1);
                attempt.restart();
            } catch (e) {
                Logger.warn("Bluetooth", String(e));
                root._fail();
            }
            return;
        }
        if (root._pairing) {
            if (d.pairing || d.connected)
                root._saw = true;
            else if (root._saw)
                root._fail();
            return;
        }
        if (BluetoothAudio.linked(d)) {
            root._ok();
            return;
        }
        if (d.connected) {
            root._saw = true;
            root._failKey = "settings.bluetooth.noAudio";
            return;
        }
        if (d.pairing || d.state === Bluez.BluetoothDeviceState.Connecting) {
            root._saw = true;
            return;
        }
        if (root._saw && d.state === Bluez.BluetoothDeviceState.Disconnected)
            root._fail();
    }

    function connect(device: var) {
        device = root._bond(device);
        if (!device)
            return;
        const addr = String(device.address || "");
        if (!addr.length)
            return;
        if (BluetoothAudio.linked(device)) {
            root._clear();
            root.errorKey = "";
            root.errorAddress = "";
            root.settled(true, addr);
            return;
        }
        if (root.busy && root.pendingAddress === addr)
            return;
        root._clear();
        root.pendingAddress = addr;
        root.errorKey = "";
        root.errorAddress = "";
        // A second bond would drop the other host, so a bonded headset is
        // only connected. Without a bond there is nothing to connect with.
        root._pairing = !(device.paired || device.bonded);
        root._failKey = !root._pairing ? "settings.bluetooth.connectFailed"
            : root.bondLost(device) ? "settings.bluetooth.bondLost" : "settings.bluetooth.pairFailed";
        Bluetooth.setDiscovering(false);
        try {
            if (root._pairing) {
                BluetoothClassic.pair(device);
            } else {
                if (!device.trusted)
                    device.trusted = true;
                // BlueZ refuses Connect on a link that is already up.
                if (device.connected)
                    BluetoothAudio.ask(device);
                else if (device.connect)
                    device.connect();
            }
        } catch (e) {
            Logger.warn("Bluetooth", String(e));
            root._fail();
            return;
        }
        attempt.interval = Math.max(root._pairing ? Motion.bluetoothPairMs : Motion.bluetoothConnectMs, 1);
        attempt.restart();
    }

    function disconnect(device: var) {
        if (device && device.disconnect)
            device.disconnect();
    }

    function forget(device: var) {
        if (!device)
            return;
        const addr = String(device.address || "");
        if (addr.length && root._saved[addr]) {
            const next = Object.assign({}, root._saved);
            delete next[addr];
            root._saved = next;
            root.savedGen += 1;
        }
        if (root.pendingAddress === addr)
            root._clear();
        if (root.errorAddress === addr) {
            root.errorKey = "";
            root.errorAddress = "";
        }
        try {
            if (device.forget)
                device.forget();
            else if (Bluetooth.adapter && Bluetooth.adapter.removeDevice)
                Bluetooth.adapter.removeDevice(device);
        } catch (e) {
            Logger.warn("Bluetooth", String(e));
        }
    }
}
