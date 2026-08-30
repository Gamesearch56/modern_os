// When audio.autoSwitchBluetooth is on, a newly appeared BlueZ sink or
// source becomes the PipeWire default. Existing endpoints at startup
// are left as-is so a user-chosen speaker is not stolen on login.
import QtQuick

QtObject {
    id: bt

    property var audio: null
    readonly property bool enabled: (audio && audio.autoBluetooth) || false

    readonly property string endpointSig: {
        const a = bt.audio;
        if (!a)
            return "";
        let s = "";
        const sinks = a.sinks;
        for (let i = 0; i < sinks.length; i++)
            s += "k" + sinks[i].id + ",";
        const sources = a.sources;
        for (let j = 0; j < sources.length; j++)
            s += "c" + sources[j].id + ",";
        return s;
    }

    property var seen: ({})
    property bool primed: false

    onEndpointSigChanged: bt.sync()

    function isBluetoothNode(n: var): bool {
        if (!n)
            return false;
        const _ = n.ready;
        const p = n.properties || {};
        const api = String(p["device.api"] || p["api.bluez5.address"] || p["bluez5.address"] || "").toLowerCase();
        if (api.indexOf("bluez") !== -1)
            return true;
        if (String(p["api.bluez5.transport"] || "").length)
            return true;
        const name = String(n.name || n.description || n.nickname || "").toLowerCase();
        return name.indexOf("bluez") !== -1 || name.indexOf("bluetooth") !== -1;
    }

    function sync() {
        const a = bt.audio;
        if (!a)
            return;
        const now = {};
        const freshSinks = [];
        const freshSources = [];
        const sinks = a.sinks;
        for (let i = 0; i < sinks.length; i++) {
            const id = "k" + sinks[i].id;
            now[id] = true;
            if (!bt.seen[id])
                freshSinks.push(sinks[i]);
        }
        const sources = a.sources;
        for (let j = 0; j < sources.length; j++) {
            const id = "c" + sources[j].id;
            now[id] = true;
            if (!bt.seen[id])
                freshSources.push(sources[j]);
        }
        if (!bt.primed) {
            if (Object.keys(now).length === 0)
                return;
            bt.seen = now;
            bt.primed = true;
            return;
        }
        if (bt.enabled) {
            for (let s = 0; s < freshSinks.length; s++) {
                if (bt.isBluetoothNode(freshSinks[s]))
                    a.setDefaultSink(freshSinks[s]);
            }
            for (let c = 0; c < freshSources.length; c++) {
                if (bt.isBluetoothNode(freshSources[c]))
                    a.setDefaultSource(freshSources[c]);
            }
        }
        bt.seen = now;
    }
}
