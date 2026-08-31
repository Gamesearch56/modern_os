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
    readonly property bool autoBluetooth: (Config.audio.autoSwitchBluetooth || "on") !== "off"
    readonly property int volumeCap: Config.audio.masterVolumeLimit ?? 100

    AudioBluetooth {
        audio: root
    }

    AudioNowPlaying {
        id: nowPlaying
        streams: root.streams
    }

    readonly property var playback: nowPlaying.playback

    // Hardware endpoints only — application streams are not switchable
    // outputs. Tracked so nickname/description bind (docs/DECISIONS.md
    // never-hardcode-device-ids: labels come from PipeWire).
    readonly property list<PwNode> sinks: {
        const t = root.trackedNodes;
        const out = [];
        for (let i = 0; i < t.length; i++) {
            if (t[i].isSink && t[i].audio)
                out.push(t[i]);
        }
        return out;
    }
    readonly property list<PwNode> sources: {
        const t = root.trackedNodes;
        const out = [];
        for (let i = 0; i < t.length; i++) {
            if (!t[i].isSink && t[i].audio)
                out.push(t[i]);
        }
        return out;
    }
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

    readonly property real volume: {
        const n = root.sink;
        if (!n || !n.audio)
            return 0;
        return Math.round(n.audio.volume * 100);
    }
    readonly property bool muted: root.sink?.audio?.muted ?? false
    readonly property real sourceVolume: {
        const n = root.source;
        if (!n || !n.audio)
            return 0;
        return Math.round(n.audio.volume * 100);
    }
    readonly property bool sourceMuted: root.source?.audio?.muted ?? false

    onVolumeCapChanged: {
        if (root.volume > root.volumeCap)
            root.setVolume(root.volumeCap);
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
        return n.nickname || n.description || n.name || "";
    }

    function streamAppId(n: var): string {
        if (!n)
            return "";
        const _ = n.ready;
        const p = n.properties || {};
        return String(p["application.name"] || p["application.id"] || n.nickname || "").trim();
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

    function setVolume(percent: real) {
        if (!root.sink?.audio)
            return;
        const cap = root.volumeCap;
        const v = Math.max(0, Math.min(cap, percent)) / 100;
        root.sink.audio.volume = v;
    }

    function adjustVolume(deltaPercent: real) {
        root.setVolume(root.volume + deltaPercent);
    }

    function toggleMute() {
        if (!root.sink?.audio)
            return;
        root.sink.audio.muted = !root.sink.audio.muted;
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
    }

    function setDefaultSource(node: var) {
        Pipewire.preferredDefaultAudioSource = node;
    }

    function setStreamVolume(node: var, percent: real) {
        if (!node?.audio)
            return;
        node.audio.volume = Math.max(0, Math.min(100, percent)) / 100;
        if (percent > 0)
            node.audio.muted = false;
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
