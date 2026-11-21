pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import "../Commons"

// Whether a Bluetooth headset has audio, not only a link. BlueZ reports
// Connected as soon as the radio link is up; PipeWire has a bluez node
// only once A2DP or the headset profile runs.
// Multipoint buds that come back to this computer often open a bare link
// and wait for the host to start A2DP. The kernel drops a link without a
// channel after about two seconds, so the buds reconnect in a loop and
// never play. A saved headset on such a link is asked for A2DP once per
// link. Only an existing link is asked, so nothing pages the headset.

Singleton {
    id: root

    readonly property string _a2dpSink: "0000110b-0000-1000-8000-00805f9b34fb"
    property var _asked: ({})
    property var _due: ({})

    // Node names carry the address: bluez_output.AA_BB_CC_DD_EE_FF.1
    readonly property string nodeSig: {
        const vals = Pipewire.nodes?.values ?? [];
        let s = "";
        for (let i = 0; i < vals.length; i++) {
            const name = String(vals[i]?.name || "");
            if (name.indexOf("bluez_") === 0)
                s += name.toUpperCase() + ",";
        }
        return s;
    }

    onNodeSigChanged: Qt.callLater(root._changed)

    Timer {
        id: wait
        interval: Math.max(Motion.bluetoothProfileMs, 1)
        onTriggered: root._ask()
    }

    function _key(device: var): string {
        return String(device?.address || "").toUpperCase().replace(/:/g, "_");
    }

    function audioUp(device: var): bool {
        const key = root._key(device);
        return key.length > 0 && root.nodeSig.indexOf("." + key) !== -1;
    }

    // A link that only counts once audio runs. Mice and keyboards have
    // no PipeWire node and count as soon as they are linked.
    function linked(device: var): bool {
        if (!device || !device.connected)
            return false;
        return !Bluetooth.isAudioDevice(device) || root.audioUp(device);
    }

    // A user Connect on a link that is already up: ask again even if
    // this link was asked once already.
    function ask(device: var) {
        const addr = String(device?.address || "");
        if (!addr.length || root.audioUp(device))
            return;
        const asked = Object.assign({}, root._asked);
        delete asked[addr];
        root._asked = asked;
        root._due = Object.assign({}, root._due, { [addr]: true });
        wait.restart();
    }

    function _changed() {
        root.watch();
        BluetoothLink.settle();
    }

    function watch() {
        const list = Bluetooth._list(Bluetooth.devices);
        const asked = Object.assign({}, root._asked);
        const due = {};
        let any = false;
        for (let i = 0; i < list.length; i++) {
            const d = list[i];
            const addr = String(d?.address || "");
            if (!addr.length)
                continue;
            if (!d.connected) {
                delete asked[addr];
                continue;
            }
            if (asked[addr] || d.blocked || !d.paired || !d.trusted || !Bluetooth.isAudioDevice(d) || root.audioUp(d))
                continue;
            due[addr] = true;
            any = true;
        }
        root._asked = asked;
        root._due = due;
        if (any && !wait.running)
            wait.restart();
    }

    function _ask() {
        const list = Bluetooth._list(Bluetooth.devices);
        const asked = Object.assign({}, root._asked);
        for (let i = 0; i < list.length; i++) {
            const d = list[i];
            const addr = String(d?.address || "");
            if (!root._due[addr] || asked[addr] || !d.connected || root.audioUp(d))
                continue;
            const path = String(d.dbusPath || "");
            if (!path.length)
                continue;
            asked[addr] = true;
            Logger.info("Bluetooth", "starting A2DP on a link without audio");
            Quickshell.execDetached(["busctl", "call", "org.bluez", path, "org.bluez.Device1",
                "ConnectProfile", "s", root._a2dpSink]);
        }
        root._asked = asked;
        root._due = {};
    }
}
