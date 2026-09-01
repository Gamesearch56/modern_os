// Remember per-app PipeWire stream volume in config.json so a
// Quickshell reload does not snap every sink-input back to 100%.
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
            s += String(n.id) + ":" + a.streamAppId(n) + ",";
        }
        return s;
    }

    onStreamSigChanged: root.applyAll()

    readonly property var disk: Config.audio.perAppVolume || ({})
    onDiskChanged: root.applyAll()

    function lookup(key: string): real {
        if (!key.length)
            return -1;
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
        const want = root.lookup(a.streamAppId(n));
        if (want < 0)
            return;
        if (Math.round(n.audio.volume * 100) === want)
            return;
        n.audio.volume = want / 100;
    }
}
