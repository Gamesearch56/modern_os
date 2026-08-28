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
        objects: [root.sink, root.source]
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
        const sinks = [];
        for (let i = 0; i < root.nodes.values.length; i++) {
            const n = root.nodes.values[i];
            if (n.isSink && n.isStream === false)
                sinks.push(n);
        }
        if (sinks.length < 2)
            return;
        let idx = sinks.findIndex(n => n === root.sink);
        const next = sinks[(idx + 1) % sinks.length];
        Pipewire.preferredDefaultAudioSink = next;
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
