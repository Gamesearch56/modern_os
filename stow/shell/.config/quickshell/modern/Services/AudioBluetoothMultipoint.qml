// Multipoint headphones stay with the other device until this PC is
// producing sound. An open browser is not sound: Vivaldi/Chromium keep
// one uncorked "Playback" stream and report MPRIS Playing for a tab
// that is silent. Android, macOS and PipeWire's AVRCP player all switch
// on audible playback, then release the transport when it stops.
import QtQuick
import Quickshell.Services.Pipewire
import "../Commons"

QtObject {
    id: root

    property var audio: null
    property var btAuto: null
    readonly property bool enabled: !!(audio && audio.autoBluetooth)
    // Linear peak. Silence and a muted tab sit under this; speech does not.
    readonly property real soundFloor: 0.015

    readonly property string candSig: {
        const a = root.audio;
        if (!a)
            return "";
        const vals = a.streams || [];
        let s = "";
        for (let i = 0; i < vals.length; i++) {
            if (root._candidate(vals[i]))
                s += String(vals[i].id) + ",";
        }
        return s;
    }

    readonly property string btSig: {
        const a = root.audio;
        if (!a || !root.btAuto)
            return "";
        const sinks = a.sinks || [];
        let s = "";
        for (let i = 0; i < sinks.length; i++) {
            if (root.btAuto.isBluetoothNode(sinks[i]))
                s += String(sinks[i].id) + ",";
        }
        return s;
    }

    // A multipoint headset reports 0 volume here while the other device
    // held it, and WirePlumber restores that 0 on the next connect, so the
    // sink is silent at the shown master level. -1 when not Bluetooth.
    readonly property real _btSinkVolume: {
        const a = root.audio;
        const n = a ? a.sink : null;
        if (!n || !n.audio || !root.btAuto || !root.btAuto.isBluetoothNode(n))
            return -1;
        void n.audio.volume;
        return Math.round(n.audio.volume * 100);
    }
    on_BtSinkVolumeChanged: {
        if (root._btSinkVolume === 0)
            holdVolume.restart();
    }

    property Timer holdVolume: Timer {
        interval: Math.max(Motion.shortMs, 1)
        repeat: false
        onTriggered: {
            const a = root.audio;
            if (!a || root._btSinkVolume !== 0 || a.muted || a.volume <= 0)
                return;
            a.applyDevice();
        }
    }

    property var _watch: []
    property bool _audible: false
    property bool _wantAudio: false
    property bool _releasing: false
    property var _tried: ({})
    readonly property bool _powered: Bluetooth.powered

    property Instantiator meters: Instantiator {
        model: root._watch
        delegate: PwNodePeakMonitor {
            required property var modelData
            node: modelData
            enabled: root.enabled && node !== null
            onPeakChanged: root._sample()
        }
        onObjectAdded: root._sample()
        // The removed meter still counts until this handler returns.
        onObjectRemoved: Qt.callLater(root._sample)
    }

    property Timer confirm: Timer {
        interval: Math.max(Motion.longMs, 1)
        repeat: false
        onTriggered: {
            if (root._level() < root.soundFloor)
                return;
            root._audible = true;
            root._sync();
        }
    }

    property Timer idle: Timer {
        interval: Math.max(Motion.bluetoothIdleMs, 1)
        repeat: false
        onTriggered: root._release()
    }

    Component.onCompleted: {
        root._retarget();
        if (root._btSinkVolume === 0)
            holdVolume.restart();
    }
    onEnabledChanged: { root._tried = ({}); root._sync(); }
    on_PoweredChanged: { root._tried = ({}); root._sync(); }
    onCandSigChanged: { root._retarget(); root._sample(); root._sync(); }
    onBtSigChanged: root._sync()

    function _candidate(n: var): bool {
        if (!n)
            return false;
        void n.ready;
        void n.audio;
        void n.properties;
        if (!n.audio || n.audio.muted)
            return false;
        if (n.ready === false)
            return false;
        const p = n.properties || {};
        const mediaClass = String(p["media.class"] || "").toLowerCase();
        if (mediaClass.indexOf("input") !== -1)
            return false;
        const corked = String(p["pulse.corked"] || "").toLowerCase();
        return corked !== "true" && corked !== "1";
    }

    function _retarget() {
        const a = root.audio;
        const next = [];
        if (a) {
            const vals = a.streams || [];
            for (let i = 0; i < vals.length; i++) {
                if (root._candidate(vals[i]))
                    next.push(vals[i]);
            }
        }
        root._watch = next;
    }

    function _level(): real {
        let peak = 0;
        const n = root.meters.count;
        for (let i = 0; i < n; i++) {
            const m = root.meters.objectAt(i);
            const p = m ? Number(m.peak) || 0 : 0;
            if (p > peak)
                peak = p;
        }
        return peak;
    }

    function _sample() {
        const hot = root._watch.length > 0 && root._level() >= root.soundFloor;
        if (hot) {
            if (root._audible)
                return;
            if (!confirm.running)
                confirm.restart();
            return;
        }
        confirm.stop();
        if (!root._audible)
            return;
        root._audible = false;
        root._sync();
    }

    function _playing(): bool {
        return root._audible;
    }

    function _sync() {
        const sink = root.btAuto;
        if (!root.enabled) {
            idle.stop();
            confirm.stop();
            root._audible = false;
            root._wantAudio = false;
            if (sink)
                sink.wantSink = false;
            return;
        }
        if (root._playing()) {
            idle.stop();
            root._wantAudio = true;
            if (sink)
                sink.wantSink = true;
            root._connect();
            root._route();
            return;
        }
        // A pick in Settings holds the headset through one idle wait.
        if (Bluetooth.userSink && !root._wantAudio) {
            idle.restart();
            return;
        }
        // A headset that showed up with nothing playing is not a pause
        // in music. Route away now so the other device keeps the stream.
        if (!root._wantAudio) {
            if (root.btSig.length > 0 && !root._releasing)
                root._release();
            return;
        }
        idle.restart();
    }

    function _connect() {
        if (!Bluetooth.autoAudio || !Bluetooth.powered)
            return;
        const list = Bluetooth.pairedAudio();
        const tried = Object.assign({}, root._tried);
        for (let i = 0; i < list.length; i++) {
            const d = list[i];
            const addr = String(d.address);
            if (!d.trusted)
                d.trusted = true;
            // Connected may be only the call link while the other device has music.
            if ((d.connected && root._hasSink(addr)) || tried[addr])
                continue;
            tried[addr] = true;
            Qt.callLater(() => Bluetooth.connectDevice(d, false));
        }
        root._tried = tried;
    }

    function _hasSink(addr: string): bool {
        const a = root.audio;
        const b = root.btAuto;
        if (!a || !b)
            return false;
        const want = String(addr || "").toLowerCase();
        const flat = want.replace(/:/g, "_");
        const sinks = a.sinks || [];
        for (let i = 0; i < sinks.length; i++) {
            const n = sinks[i];
            if (!b.isBluetoothNode(n))
                continue;
            void n.properties;
            const p = n.properties || {};
            const at = String(p["api.bluez5.address"] || p["bluez5.address"] || "").toLowerCase();
            if (at === want || String(n.name || "").toLowerCase().indexOf(flat) !== -1)
                return true;
        }
        return false;
    }

    function _route() {
        const a = root.audio;
        const b = root.btAuto;
        if (!a || !b)
            return;
        const sinks = a.sinks || [];
        for (let i = 0; i < sinks.length; i++) {
            if (!b.isBluetoothNode(sinks[i]))
                continue;
            b.preferA2dp(sinks[i]);
            a.setDefaultSink(sinks[i]);
            return;
        }
    }

    function _release() {
        if (root._releasing || !root.enabled || root._playing())
            return;
        root._releasing = true;
        root._wantAudio = false;
        root._tried = ({});
        Bluetooth.userSink = false;
        if (root.btAuto)
            root.btAuto.wantSink = false;
        // Stay connected. With no stream on the headset sink, WirePlumber
        // suspends it and frees the transport, so the other device can
        // play. Sound here moves the default back and the headset follows.
        if (root.btAuto) {
            root.btAuto.applyFallback(true);
            root.btAuto.applyFallback(false);
        }
        root._releasing = false;
    }
}
