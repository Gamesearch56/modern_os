pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import "../Commons"

// Whether a Bluetooth headset has audio, not only a link. BlueZ reports
// Connected as soon as the radio link is up; PipeWire has a bluez node
// only once A2DP or the headset profile runs.
// A2DP is never started on a link by itself: the headset opens it, and
// BlueZ falls back to opening it about three seconds after the link. A
// third request in that window crosses theirs; each side then waits on
// the other until AVDTP times out and the headset drops the link. Only a
// user Connect on a link that is already up asks, after that window.

Singleton {
    id: root

    readonly property string _a2dpSink: "0000110b-0000-1000-8000-00805f9b34fb"
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

    onNodeSigChanged: Qt.callLater(BluetoothLink.settle)

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

    // BlueZ refuses Connect on a link that is already up, so a user
    // Connect there asks for A2DP instead.
    function ask(device: var) {
        const addr = String(device?.address || "");
        if (!addr.length || root.audioUp(device))
            return;
        root._due = Object.assign({}, root._due, { [addr]: true });
        wait.restart();
    }

    function _ask() {
        const list = Bluetooth._list(Bluetooth.devices);
        for (let i = 0; i < list.length; i++) {
            const d = list[i];
            const addr = String(d?.address || "");
            if (!root._due[addr] || !d.connected || root.audioUp(d))
                continue;
            const path = String(d.dbusPath || "");
            if (!path.length)
                continue;
            Logger.info("Bluetooth", "starting A2DP on a link without audio");
            Quickshell.execDetached(["busctl", "call", "org.bluez", path, "org.bluez.Device1",
                "ConnectProfile", "s", root._a2dpSink]);
        }
        root._due = {};
    }
}
