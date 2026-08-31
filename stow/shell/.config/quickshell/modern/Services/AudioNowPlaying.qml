// Unmuted sink-input stream for the bar media pill. Browsers often
// play YouTube with no MPRIS player; PipeWire still has a stream.
import QtQuick

QtObject {
    id: root

    property var streams: []

    readonly property var playback: {
        const vals = root.streams || [];
        for (let i = 0; i < vals.length; i++) {
            const n = vals[i];
            if (!n || !n.audio || n.audio.muted)
                continue;
            if (n.isSink === false)
                continue;
            void n.ready;
            void n.properties;
            if (n.ready === false)
                continue;
            const p = n.properties || {};
            const corked = String(p["pulse.corked"] || "").toLowerCase();
            if (corked === "true" || corked === "1")
                continue;
            const state = String(p["stream.activity"] || p["node.state"] || "").toLowerCase();
            if (state === "idle" || state === "suspended" || state === "corked")
                continue;
            if (!root.streamTitle(n).length)
                continue;
            return n;
        }
        return null;
    }

    function streamTitle(n: var): string {
        if (!n)
            return "";
        const p = n.properties || {};
        const title = String(p["media.name"] || p["media.title"] || "").trim();
        if (title.length)
            return title;
        return String(p["application.name"] || p["application.id"] || "").trim();
    }
}
