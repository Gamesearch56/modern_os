// Launcher overlay state plus frecency store. File I/O lives here so
// Modules/Launcher never touches disk (layer rule).
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property bool open: false
    property var usage: ({})

    readonly property string home: Quickshell.env("HOME")

    FileView {
        id: file
        path: `${root.home}/.local/state/modern/launcher-usage.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.usage = JSON.parse(text());
            } catch (e) {
                Logger.warn("Launcher", "launcher-usage.json parse failed: " + e);
                root.usage = ({});
            }
        }
        onLoadFailed: root.usage = ({})
    }

    function toggle() { root.open = !root.open; }
    function show() { root.open = true; }
    function hide() { root.open = false; }

    function score(id: string): real {
        const e = root.usage[id];
        if (!e)
            return 0;
        const hours = Math.max(0, (Date.now() - (e.last || 0)) / 3600000);
        const decay = 1 / (1 + hours / 24);
        return (e.count || 0) * decay;
    }

    function record(id: string) {
        try {
            const next = Object.assign({}, root.usage);
            const prev = next[id] || { count: 0, last: 0 };
            next[id] = { count: prev.count + 1, last: Date.now() };
            root.usage = next;
            file.setText(JSON.stringify(next));
        } catch (e) {
            Logger.error("Launcher", "failed to persist usage: " + e);
        }
    }

    function mostUsed(limit: int): var {
        const ids = Object.keys(root.usage);
        ids.sort((a, b) => root.score(b) - root.score(a));
        return ids.slice(0, limit);
    }

    function query(text: string): var {
        const entries = DesktopEntries.applications.values;
        const needle = (text || "").trim().toLowerCase();
        let out = [];
        for (let i = 0; i < entries.length; i++) {
            const e = entries[i];
            if (e.noDisplay)
                continue;
            const name = (e.name || "").toLowerCase();
            const generic = (e.genericName || "").toLowerCase();
            if (needle.length === 0 || name.indexOf(needle) !== -1 || generic.indexOf(needle) !== -1 || root._subseq(name, needle)) {
                out.push({
                    id: e.id || e.name,
                    name: e.name,
                    genericName: e.genericName,
                    icon: e.icon,
                    exec: e,
                    score: root.score(e.id || e.name)
                });
            }
        }
        out.sort((a, b) => b.score - a.score || a.name.localeCompare(b.name));
        const limit = Config.launcher.resultCount ?? 9;
        return out.slice(0, needle.length === 0 ? (Config.launcher.mostUsedGridSize ?? 8) : limit);
    }

    function launch(item: var) {
        try {
            if (!item)
                return;
            root.record(item.id);
            if (item.exec?.execute)
                item.exec.execute();
            root.hide();
        } catch (e) {
            Logger.error("Launcher", String(e));
        }
    }

    function _subseq(hay: string, needle: string): bool {
        let j = 0;
        for (let i = 0; i < hay.length && j < needle.length; i++) {
            if (hay[i] === needle[j])
                j++;
        }
        return j === needle.length;
    }
}
