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
            if (!n)
                continue;
            void n.ready;
            void n.audio;
            void n.properties;
            if (!n.audio || n.audio.muted)
                continue;
            if (n.ready === false)
                continue;
            const p = n.properties || {};
            const mediaClass = String(p["media.class"] || "").toLowerCase();
            if (mediaClass.indexOf("input") !== -1)
                continue;
            const corked = String(p["pulse.corked"] || "").toLowerCase();
            if (corked === "true" || corked === "1")
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

    function findStream(hint: string): var {
        const q = String(hint || "").trim().toLowerCase();
        if (!q.length)
            return null;
        const vals = root.streams || [];
        for (let i = 0; i < vals.length; i++) {
            const n = vals[i];
            if (!n)
                continue;
            void n.ready;
            void n.audio;
            void n.properties;
            if (!n.audio)
                continue;
            const p = n.properties || {};
            const mediaClass = String(p["media.class"] || "").toLowerCase();
            if (mediaClass.indexOf("input") !== -1)
                continue;
            const hay = [
                p["application.name"],
                p["application.id"],
                p["application.process.binary"],
                p["application.desktop"],
                n.nickname
            ].join(" ").toLowerCase();
            if (hay.indexOf(q) !== -1)
                return n;
        }
        return null;
    }
}
