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

    // Hardware endpoints only — application streams are not switchable
    // outputs. Tracked so nickname/description bind (docs/DECISIONS.md
    // never-hardcode-device-ids: labels come from PipeWire).
    readonly property list<PwNode> sinks: {
        const t = root.trackedNodes;
        const out = [];
        for (let i = 0; i < t.length; i++) {
            if (t[i].isSink)
                out.push(t[i]);
        }
        return out;
    }
    readonly property list<PwNode> sources: {
        const t = root.trackedNodes;
        const out = [];
        for (let i = 0; i < t.length; i++) {
            if (!t[i].isSink)
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

    PwObjectTracker {
        objects: root.trackedNodes
    }

    function nodeLabel(n: var): string {
        if (!n)
            return "";
        const _ = n.ready;
        return n.nickname || n.description || n.name || "";
    }

    function setVolume(percent: real) {
        if (!root.sink?.audio)
            return;
        const cap = Config.audio.masterVolumeLimit ?? 100;
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

    IpcHandler {
        target: "audio"
        function volumeUp() { root.adjustVolume(5); }
        function volumeDown() { root.adjustVolume(-5); }
        function mute() { root.toggleMute(); }
    }
}
