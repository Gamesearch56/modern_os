pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

// Readies a headset sink before it becomes the default. For a few
// seconds after a reconnect, buds such as the Pixel Buds Pro 2 accept
// A2DP audio but queue it and play it seconds late, and the backlog
// stays until the stream stops, so video runs out of sync. Silence
// absorbs that window; suspending the sink afterwards drops the backlog,
// and the stream that moves over starts on a clean transport.

Singleton {
    id: root

    property var _node: null
    property var _audio: null

    function warm(node: var, audio: var) {
        if (!node || !audio)
            return;
        root._node = node;
        root._audio = audio;
        if (feed.running || reset.running)
            return;
        feed.command = ["timeout", String(Math.max(0.5, Motion.bluetoothWarmMs / 1000)),
            "pacat", "--raw", "-d", String(node.name), "/dev/zero"];
        feed.running = true;
    }

    function _finish() {
        const node = root._node;
        const audio = root._audio;
        root._node = null;
        root._audio = null;
        if (node && audio && (audio.sinks || []).indexOf(node) !== -1)
            audio.setDefaultSink(node);
    }

    Process {
        id: feed
        running: false
        onExited: (code) => {
            // timeout exits 124 when it stops the feed on schedule.
            if (code !== 0 && code !== 124)
                Logger.warn("Bluetooth", "headset warm-up exited " + code);
            if (!root._node)
                return;
            reset.command = ["sh", "-c", "pactl suspend-sink \"$1\" 1; pactl suspend-sink \"$1\" 0",
                "sh", String(root._node.name)];
            reset.running = true;
        }
    }

    Process {
        id: reset
        running: false
        onExited: root._finish()
    }
}
