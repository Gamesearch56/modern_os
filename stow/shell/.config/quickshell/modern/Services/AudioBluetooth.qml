// When audio.autoSwitchBluetooth is on, a newly appeared BlueZ *sink*
// becomes the PipeWire default (A2DP). The BlueZ source is never made
// default automatically — that forces HFP and blocks phone multipoint.
// On disconnect, an explicit fallback wins; otherwise the last
// non-Bluetooth endpoint is restored. Startup endpoints are left alone.
import Quickshell
import QtQuick
import "../Commons"

QtObject {
    id: bt

    property var audio: null
    readonly property bool enabled: (audio && audio.autoBluetooth && !audio.outputPinned) || false

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
    property bool _applying: false
    property int _settle: 0
    // Set while sound is actually playing. A new BlueZ sink must not
    // become the speaker just because a browser opened a silent stream.
    property bool wantSink: false
    readonly property AudioBluetoothHold hold: AudioBluetoothHold { audio: bt.audio; bt: bt }

    // USB mics (FOX) often expose a playback node on the same card.
    // WirePlumber follows the source onto that sink after BT drops;
    // keep asserting the chosen speaker for one recording-chrome beat.
    property Timer settle: Timer {
        interval: Motion.extraLongMs
        repeat: true
        onTriggered: bt._tickSettle()
    }

    onEndpointSigChanged: bt.sync()

    function nodeKey(n: var): string {
        if (!n)
            return "";
        const ids = bt.nodeIds(n);
        return ids.length ? ids[0] : "";
    }

    function nodeIds(n: var): var {
        if (!n)
            return [];
        const _ = n.ready;
        const raw = [n.name, n.description, n.nickname, n.id];
        const out = [];
        for (let i = 0; i < raw.length; i++) {
            const s = String(raw[i] || "");
            if (s.length && out.indexOf(s) === -1)
                out.push(s);
        }
        return out;
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
        if (!n || bt.hold.isHold(n))
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
        if (!bt._applying)
            bt._stopSettle();
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

    function _matches(n: var, key: string): bool {
        if (!n || !key)
            return false;
        return bt.nodeIds(n).indexOf(key) !== -1;
    }

    function findByKey(list: var, key: string): var {
        if (!key || !list)
            return null;
        for (let i = 0; i < list.length; i++) {
            if (bt._matches(list[i], key))
                return list[i];
        }
        return null;
    }

    function _want(isSink: bool): string {
        void Config.generation;
        const explicit = String(isSink
            ? (Config.audio.fallbackSink || "")
            : (Config.audio.fallbackSource || ""));
        if (explicit.length)
            return explicit;
        return String(isSink
            ? (Config.audio.lastSink || "")
            : (Config.audio.lastSource || ""));
    }

    function applyFallback(isSink: bool) {
        const a = bt.audio;
        if (!a || (isSink && bt.hold.parked && bt.hold.active))
            return;
        const want = bt._want(isSink);
        if (!want.length)
            return;
        const node = bt.findByKey(isSink ? a.sinks : a.sources, want);
        if (!node)
            return;
        const cur = isSink ? a.sink : a.source;
        if (bt._matches(cur, want))
            return;
        bt._applying = true;
        if (isSink)
            a.setDefaultSink(node);
        else
            a.setDefaultSource(node);
        // After a shell reload the preferred node can already equal this
        // one while PipeWire still defaults to the headset.
        Quickshell.execDetached(["wpctl", "set-default", String(node.id)]);
        bt._applying = false;
    }

    function _sinkOk(): bool {
        const want = bt._want(true);
        return !want.length || bt._matches(bt.audio ? bt.audio.sink : null, want);
    }

    function _sourceOk(): bool {
        const want = bt._want(false);
        return !want.length || bt._matches(bt.audio ? bt.audio.source : null, want);
    }

    function _stopSettle() {
        bt._settle = 0;
        settle.stop();
    }

    function _tickSettle() {
        if (bt._settle <= 0) {
            bt._stopSettle();
            return;
        }
        bt._settle -= 1;
        bt.applyFallback(false);
        bt.applyFallback(true);
        if (bt._sinkOk() && bt._sourceOk())
            bt._stopSettle();
    }

    function _armSettle() {
        bt.applyFallback(false);
        bt.applyFallback(true);
        const beat = Math.max(1, Motion.extraLongMs);
        bt._settle = Math.max(3, Math.ceil(Motion.recordingChromeMs / beat));
        settle.restart();
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
        let tookBt = false;
        if (bt.enabled && (bt.wantSink || Bluetooth.userSink)) {
            for (let s = 0; s < freshSinks.length; s++) {
                if (bt.isBluetoothNode(freshSinks[s])) {
                    bt._stopSettle();
                    bt.preferA2dp(freshSinks[s]);
                    a.setDefaultSink(freshSinks[s]);
                    tookBt = true;
                }
            }
        }
        const dropSink = goneBtSink && bt.btSinkId.length && !now[bt.btSinkId];
        const dropSource = goneBtSource && bt.btSourceId.length && !now[bt.btSourceId];
        if (!tookBt && (dropSink || dropSource))
            bt._armSettle();
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

    function preferA2dp(n: var) {
        const card = bt.cardName(n);
        if (!card.length)
            return;
        Quickshell.execDetached(["pactl", "set-card-profile", card, "a2dp-sink"]);
    }

    function cardName(n: var): string {
        if (!n)
            return "";
        void n.ready;
        void n.properties;
        const p = n.properties || {};
        let addr = String(p["api.bluez5.address"] || p["bluez5.address"] || "").trim();
        if (!addr.length) {
            const name = String(n.name || "");
            const m = name.match(/bluez_output\.([0-9A-Fa-f_]+)/);
            if (m)
                return "bluez_card." + m[1];
            return "";
        }
        return "bluez_card." + addr.replace(/:/g, "_");
    }
}
