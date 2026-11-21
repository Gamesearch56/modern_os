pragma Singleton

import Quickshell
import QtQuick
import "../Commons"

// Mediaplayer preferences in config.json → player. Volume, mute and repeat
// follow the last window; a change shows at once and is written after a
// short pause, like ViewerPrefs. The seek steps are only read.
Singleton {
    id: root

    readonly property real volumeStep: 0.05

    property real volume: root._clamp(Config.player.volume, 0, 1, 1)
    property bool muted: Config.player.muted !== false
    property bool loop: Config.player.loop !== false
    readonly property int seekSeconds: Math.round(root._clamp(Config.player.seekSeconds, 1, 60, 5))
    readonly property int jumpSeconds: Math.round(root._clamp(Config.player.jumpSeconds, 5, 600, 60))

    property var _pending: ({})

    function _clamp(value: var, low: real, high: real, fallback: real): real {
        const n = Number(value);
        return isFinite(n) ? Math.max(low, Math.min(high, n)) : fallback;
    }

    function _keep(name: string, value: var) {
        const next = Object.assign({}, root._pending);
        next[name] = value;
        root._pending = next;
        writeSoon.restart();
    }

    function setVolume(value: real) {
        root.volume = Math.round(root._clamp(value, 0, 1, root.volume) * 100) / 100;
        root._keep("volume", root.volume);
        if (root.muted && root.volume > 0)
            root.setMuted(false);
    }

    function nudgeVolume(steps: int) {
        root.setVolume(root.volume + steps * root.volumeStep);
    }

    function setMuted(on: bool) {
        root.muted = on;
        root._keep("muted", on);
    }

    function setLoop(on: bool) {
        root.loop = on;
        root._keep("loop", on);
    }

    function flush() {
        writeSoon.stop();
        const pending = root._pending;
        root._pending = ({});
        for (const name in pending)
            ConfigWrite.set("player." + name, pending[name]);
    }

    Timer {
        id: writeSoon
        interval: Motion.configWriteMs
        onTriggered: root.flush()
    }
}
