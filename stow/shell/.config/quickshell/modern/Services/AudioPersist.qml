// Remember per-app PipeWire stream volume in config.json. Spotify (and
// similar clients) drop the sink-input and start a new one at 100% on
// every track; WirePlumber may also restore 100% a beat later.
import QtQuick
import "../Commons"

QtObject {
    id: root

    property var audio: null
    property var live: ({})

    readonly property string streamSig: {
        const a = root.audio;
        if (!a)
            return "";
        void a.streams;
        const list = a.streams;
        let s = "";
        for (let i = 0; i < list.length; i++) {
            const n = list[i];
            if (!n)
                continue;
            void n.ready;
            void n.properties;
            void n.audio;
            const vol = n.audio ? Math.round(n.audio.volume * 100) : -1;
            s += String(n.id) + ":" + (n.ready ? "1" : "0") + ":"
                + a.streamAppId(n) + ":" + vol + ",";
        }
        return s;
    }

    onStreamSigChanged: root.schedule()

    readonly property var disk: Config.audio.perAppVolume || ({})
    onDiskChanged: root.schedule()

    // QtObject has no default child list — Timer must be a named property.
    property Timer settle: Timer {
        interval: Motion.mediumMs
        onTriggered: root.applyAll()
    }

    function schedule() {
        root.applyAll();
        settle.restart();
    }

    function lookup(key: string): real {
        if (!key.length)
            return -1;
        const hit = root._lookupExact(key);
        if (hit >= 0)
            return hit;
        const lower = key.toLowerCase();
        const mem = root.live || {};
        for (const k in mem) {
            if (String(k).toLowerCase() === lower)
                return Number(mem[k]);
        }
        const disk = root.disk;
        if (disk) {
            for (const k in disk) {
                if (String(k).toLowerCase() === lower)
                    return Number(disk[k]);
            }
        }
        return -1;
    }

    function _lookupExact(key: string): real {
        const mem = root.live || {};
        if (mem[key] !== undefined && mem[key] !== null)
            return Number(mem[key]);
        const disk = root.disk;
        if (disk && disk[key] !== undefined && disk[key] !== null)
            return Number(disk[key]);
        return -1;
    }

    function remember(key: string, percent: real): var {
        const v = Math.round(Math.max(0, Math.min(100, percent)));
        const next = {};
        const disk = root.disk;
        const mem = root.live || {};
        if (disk) {
            for (const k in disk)
                next[k] = disk[k];
        }
        for (const k in mem)
            next[k] = mem[k];
        next[key] = v;
        root.live = next;
        return next;
    }

    function applyAll() {
        const a = root.audio;
        if (!a)
            return;
        const list = a.streams;
        for (let i = 0; i < list.length; i++)
            root.applyOne(list[i]);
    }

    function applyOne(n: var) {
        const a = root.audio;
        if (!a || !n || !n.audio)
            return;
        if (n.ready === false)
            return;
        const want = root.lookup(a.streamAppId(n));
        if (want < 0)
            return;
        if (Math.round(n.audio.volume * 100) === want)
            return;
        n.audio.volume = want / 100;
    }
}
