// PipeWire audio. Owns default sink/source, per-app streams, mute and
// volume. The audio widget never talks to wpctl/pactl — only here.
pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property var nodes: Pipewire.nodes
    readonly property bool autoBluetooth: (Config.audio.autoSwitchBluetooth || "on") === "on"
    // A wired output picked by hand: no Bluetooth auto-routing until a
    // headset is picked or connected by hand (Bluetooth.connectDevice).
    readonly property bool outputPinned: Config.audio.pinOutput === true
    readonly property int volumeCap: Config.audio.masterVolumeLimit ?? 100

    AudioBluetooth {
        id: btAuto
        audio: root
    }

    AudioBluetoothMultipoint { audio: root; btAuto: btAuto }

    AudioNowPlaying {
        id: nowPlaying
        streams: root.streams
    }

    AudioPersist {
        id: persist
        audio: root
    }

    // Logical master, written to every node that shares the default
    // sink's name (WirePlumber can expose duplicates). Per-app sliders
    // are the stream level; they are not multiplied by this again.
    property int _master: -1
    property bool _userMuted: false

    readonly property var playback: nowPlaying.playback

    // Hardware endpoints only — application streams are not switchable
    // outputs. Tracked so nickname/description bind (docs/DECISIONS.md
    // never-hardcode-device-ids: labels come from PipeWire).
    readonly property list<PwNode> sinks: Array.from(root.trackedNodes)
        .filter(n => n.isSink && n.audio && !btAuto.hold.isHold(n))
    readonly property list<PwNode> sources: Array.from(root.trackedNodes)
        .filter(n => !n.isSink && n.audio)
    // What pickers show as the output: the headset while sound is parked
    // on its silent hold, the hold itself if the headset has no sink yet.
    readonly property var outputSink: btAuto.hold.shown(root.sink)
    readonly property bool outputHeld: btAuto.hold.isHold(root.outputSink)
    readonly property list<PwNode> trackedNodes: {
        const vals = root.nodes.values;
        const out = [];
        for (let i = 0; i < vals.length; i++) {
            const n = vals[i];
            if (n && n.isStream === false)
                out.push(n);
        }
        return out;
    }
    readonly property list<PwNode> streams: {
        const vals = root.nodes.values;
        const out = [];
        for (let i = 0; i < vals.length; i++) {
            const n = vals[i];
            if (n && n.isStream === true)
                out.push(n);
        }
        return out;
    }

    readonly property real _sinkVolume: {
        const n = root.sink;
        if (!n || !n.audio)
            return -1;
        void n.audio.volume;
        return Math.round(n.audio.volume * 100);
    }
    readonly property real volume: {
        if (root._master >= 0)
            return root._master;
        const cfg = Config.audio.masterVolume;
        if (cfg !== undefined && cfg !== null && Number(cfg) >= 0)
            return Math.min(root.volumeCap, Number(cfg));
        if (root._sinkVolume >= 0)
            return root._sinkVolume;
        return 0;
    }
    readonly property bool muted: root._userMuted
    readonly property real sourceVolume: {
        const n = root.source;
        if (!n || !n.audio)
            return 0;
        return Math.round(n.audio.volume * 100);
    }
    readonly property bool sourceMuted: root.source?.audio?.muted ?? false

    function _seedMaster() {
        if (root._master >= 0)
            return;
        const cfg = Config.audio.masterVolume;
        if (cfg !== undefined && cfg !== null && Number(cfg) >= 0)
            root._master = Math.min(root.volumeCap, Number(cfg));
    }

    onVolumeCapChanged: {
        if (root.volume > root.volumeCap)
            root.setVolume(root.volumeCap);
    }
    Component.onCompleted: root._seedMaster()
    onSinkChanged: {
        root._seedMaster();
        if (root._master >= 0)
            root.applyDevice();
    }

    PwObjectTracker {
        objects: root.trackedNodes
    }
    PwObjectTracker {
        objects: root.streams
    }

    function nodeLabel(n: var): string {
        if (!n)
            return "";
        const _ = n.ready;
        if (btAuto.hold.isHold(n))
            return btAuto.hold.label();
        return n.nickname || n.description || n.name || "";
    }

    function nodeKey(n: var): string {
        return btAuto.nodeKey(n);
    }

    function isBluetoothNode(n: var): bool {
        return btAuto.isBluetoothNode(n);
    }

    function streamAppId(n: var): string {
        if (!n)
            return "";
        const _ = n.ready;
        const p = n.properties || {};
        return String(p["application.name"] || p["application.id"]
            || p["application.process.binary"] || p["application.desktop"] || "").trim();
    }

    function streamLabel(n: var): string {
        const app = root.streamAppId(n);
        if (app.length)
            return app;
        return root.nodeLabel(n);
    }

    function streamIcon(n: var): string {
        if (!n)
            return "";
        const _ = n.ready;
        const p = n.properties || {};
        return String(p["application.icon-name"] || p["application.icon_name"] || p["media.icon-name"] || "").trim();
    }

    function streamTitle(n: var): string {
        const title = nowPlaying.streamTitle(n);
        return title.length ? title : root.streamLabel(n);
    }

    function findStream(hint: string): var {
        return nowPlaying.findStream(hint);
    }

    function applyDevice() {
        const raw = Math.max(0, Math.min(root.volumeCap,
            root._master >= 0 ? root._master : root.volume));
        const v = raw / 100;
        const mute = root._userMuted;
        const cap = Math.max(1, root.volumeCap) / 100;
        Quickshell.execDetached(["wpctl", "set-volume", "-l", String(cap), "@DEFAULT_AUDIO_SINK@", String(raw) + "%"]);
        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", mute ? "1" : "0"]);
        if (root.sink?.audio) {
            root.sink.audio.volume = v;
            root.sink.audio.muted = mute;
        }
    }

    function streamVolume(node: var): real {
        void persist.live;
        void persist.disk;
        void root.volume;
        const want = persist.lookup(root.streamAppId(node));
        return want >= 0 ? want : 100;
    }

    function setVolume(percent: real) {
        const cap = root.volumeCap;
        const v = Math.round(Math.max(0, Math.min(cap, percent)));
        root._master = v;
        if (v > 0)
            root._userMuted = false;
        ConfigWrite.set("audio.masterVolume", v);
        root.applyDevice();
        persist.applyAll();
    }

    function adjustVolume(deltaPercent: real) {
        const cur = root._master >= 0 ? root._master : root.volume;
        root.setVolume(cur + deltaPercent);
    }

    function toggleMute() {
        root._userMuted = !root.muted;
        root.applyDevice();
        persist.applyAll();
    }

    function setSourceVolume(percent: real) {
        if (!root.source?.audio)
            return;
        root.source.audio.volume = Math.max(0, Math.min(100, percent)) / 100;
    }

    function toggleSourceMute() {
        if (!root.source?.audio)
            return;
        root.source.audio.muted = !root.source.audio.muted;
    }

    function cycleSink() {
        const list = root.sinks;
        if (list.length < 2)
            return;
        let idx = list.findIndex(n => root.sink && n.id === root.sink.id);
        const next = list[(idx + 1) % list.length];
        root.setDefaultSink(next);
    }

    function setDefaultSink(node: var) {
        Pipewire.preferredDefaultAudioSink = node;
        btAuto.remember(node, true);
    }

    function chooseSink(node: var) {
        ConfigWrite.set("audio.pinOutput", !!node && !btAuto.isBluetoothNode(node));
        root.setDefaultSink(node);
    }

    function setDefaultSource(node: var) {
        Pipewire.preferredDefaultAudioSource = node;
        btAuto.remember(node, false);
    }

    function setStreamVolume(node: var, percent: real) {
        if (!node?.audio)
            return;
        const v = Math.max(0, Math.min(100, percent));
        const key = root.streamAppId(node);
        if (key.length)
            ConfigWrite.set("audio.perAppVolume", persist.remember(key, v));
        persist.applyOne(node);
    }

    function adjustStreamVolume(node: var, deltaPercent: real) {
        if (!node)
            return;
        root.setStreamVolume(node, root.streamVolume(node) + deltaPercent);
    }

    function toggleStreamMute(node: var) {
        if (!node?.audio)
            return;
        node.audio.muted = !node.audio.muted;
    }

    IpcHandler {
        target: "audio"
        function volumeUp() { root.adjustVolume(5); }
        function volumeDown() { root.adjustVolume(-5); }
        function mute() { root.toggleMute(); }
    }
}
