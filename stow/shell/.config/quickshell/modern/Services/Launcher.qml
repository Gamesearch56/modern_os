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

    property real _toggledAt: 0

    function toggle() {
        const now = Date.now();
        // The shortcut is delivered again when the focus grab takes the
        // still-held key. That second call would close what this one opened.
        if (root.open && now - root._toggledAt < Motion.shortMs)
            return;
        root._toggledAt = now;
        root.open = !root.open;
    }
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

    function _matches(text: string): var {
        const entries = DesktopEntries.applications.values;
        const needle = (text || "").trim().toLowerCase();
        const out = [];
        for (let i = 0; i < entries.length; i++) {
            const e = entries[i];
            if (e.noDisplay)
                continue;
            const name = (e.name || "").toLowerCase();
            const generic = (e.genericName || "").toLowerCase();
            const comment = (e.comment || "").toLowerCase();
            if (needle.length > 0 && name.indexOf(needle) === -1 && generic.indexOf(needle) === -1
                    && comment.indexOf(needle) === -1
                    && !root._keywordHit(e.keywords, needle) && !root._subseq(name, needle))
                continue;
            const own = root._filesApp(e);
            const id = e.id || e.name;
            out.push({
                id: id,
                name: own ? I18n.t("files.launcherName") : e.name,
                genericName: e.genericName,
                icon: own ? "modern-files" : Apps.resolveIcon(e.icon || e.startupClass || e.id),
                tint: false,
                exec: e,
                score: (Config.launcher.frecencyEnabled ?? true) ? root.score(id) : 0
            });
        }
        return out;
    }

    function query(text: string): var {
        const needle = (text || "").trim();
        const out = root._matches(text);
        out.sort((a, b) => b.score - a.score || a.name.localeCompare(b.name));
        const limit = Config.launcher.resultCount ?? 9;
        return out.slice(0, needle.length === 0 ? (Config.launcher.mostUsedGridSize ?? 8) : limit);
    }

    // Every installed app, A–Z. The short list stays frecency-ranked.
    function catalog(text: string): var {
        const out = root._matches(text);
        out.sort((a, b) => String(a.name || "").localeCompare(String(b.name || "")));
        return out;
    }

    function launch(item: var) {
        try {
            if (!item)
                return;
            root.record(item.id);
            const id = String(item.id || item.name || "");
            if (id.length && Hypr.raiseDesktopOrLaunch(id, item.exec)) {
                root.hide();
                return;
            }
            if (item.exec?.execute)
                item.exec.execute();
            root.hide();
        } catch (e) {
            Logger.error("Launcher", String(e));
        }
    }

    function _filesApp(e: var): bool {
        const id = String((e && e.id) || "").replace(/\.desktop$/i, "");
        return id === "modern.files";
    }

    function _keywordHit(words: var, needle: string): bool {
        const list = words || [];
        for (let i = 0; i < list.length; i++) {
            const word = String(list[i] || "").toLowerCase();
            if (word.length && word.indexOf(needle) !== -1)
                return true;
        }
        return false;
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
