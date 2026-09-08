// When audio.autoSwitchBluetooth is on, a newly appeared BlueZ sink or
// source becomes the PipeWire default. On Bluetooth disconnect, an
// explicit fallback device wins; otherwise the last non-Bluetooth
// endpoint the user chose is restored. Existing endpoints at startup
// are left as-is so a user-chosen speaker is not stolen on login.
import QtQuick
import "../Commons"

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
    property string btSinkId: ""
    property string btSourceId: ""

    onEndpointSigChanged: bt.sync()

    function nodeKey(n: var): string {
        if (!n)
            return "";
        const _ = n.ready;
        return String(n.name || n.description || n.nickname || n.id || "");
    }

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

    function remember(n: var, isSink: bool) {
        if (!n)
            return;
        const id = (isSink ? "k" : "c") + n.id;
        if (bt.isBluetoothNode(n)) {
            if (isSink)
                bt.btSinkId = id;
            else
                bt.btSourceId = id;
            return;
        }
        if (isSink)
            bt.btSinkId = "";
        else
            bt.btSourceId = "";
        const key = bt.nodeKey(n);
        if (!key.length)
            return;
        const path = isSink ? "audio.lastSink" : "audio.lastSource";
        const cur = String(isSink
            ? (Config.audio.lastSink || "")
            : (Config.audio.lastSource || ""));
        if (cur === key)
            return;
        ConfigWrite.set(path, key);
    }

    function findByKey(list: var, key: string): var {
        if (!key || !list)
            return null;
        for (let i = 0; i < list.length; i++) {
            if (bt.nodeKey(list[i]) === key)
                return list[i];
        }
        return null;
    }

    function applyFallback(isSink: bool) {
        const a = bt.audio;
        if (!a)
            return;
        void Config.generation;
        if (isSink)
            bt.btSinkId = "";
        else
            bt.btSourceId = "";
        const explicit = String(isSink
            ? (Config.audio.fallbackSink || "")
            : (Config.audio.fallbackSource || ""));
        const last = String(isSink
            ? (Config.audio.lastSink || "")
            : (Config.audio.lastSource || ""));
        const want = explicit.length ? explicit : last;
        if (!want.length)
            return;
        const node = bt.findByKey(isSink ? a.sinks : a.sources, want);
        if (!node)
            return;
        const cur = isSink ? a.sink : a.source;
        if (cur && bt.nodeKey(cur) === want)
            return;
        if (isSink)
            a.setDefaultSink(node);
        else
            a.setDefaultSource(node);
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
            now[id] = { bt: bt.isBluetoothNode(sinks[i]), sink: true };
            if (!bt.seen[id])
                freshSinks.push(sinks[i]);
        }
        const sources = a.sources;
        for (let j = 0; j < sources.length; j++) {
            const id = "c" + sources[j].id;
            now[id] = { bt: bt.isBluetoothNode(sources[j]), sink: false };
            if (!bt.seen[id])
                freshSources.push(sources[j]);
        }
        if (!bt.primed) {
            if (Object.keys(now).length === 0)
                return;
            bt.seen = now;
            bt.primed = true;
            bt.remember(a.sink, true);
            bt.remember(a.source, false);
            return;
        }
        const prev = bt.seen;
        const goneBtSink = bt._goneBluetooth(prev, now, true);
        const goneBtSource = bt._goneBluetooth(prev, now, false);
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
        if (goneBtSink && bt.btSinkId.length && !now[bt.btSinkId])
            Qt.callLater(() => bt.applyFallback(true));
        if (goneBtSource && bt.btSourceId.length && !now[bt.btSourceId])
            Qt.callLater(() => bt.applyFallback(false));
        bt.seen = now;
    }

    function _goneBluetooth(prev: var, now: var, isSink: bool): bool {
        const keys = Object.keys(prev);
        for (let i = 0; i < keys.length; i++) {
            const id = keys[i];
            if (now[id])
                continue;
            const rec = prev[id];
            if (rec && rec.bt && rec.sink === isSink)
                return true;
        }
        return false;
    }
}
