// Locale XDG user dirs (Bilder vs Pictures). Capture defaults that still
// point at the English stock paths resolve here instead of creating a
// second folder next to Nautilus.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string home: Paths.home
    readonly property string pictures: root._dir("PICTURES", "Pictures")
    readonly property string videos: root._dir("VIDEOS", "Videos")
    readonly property string wallpapers: root.pictures + "/Wallpapers"
    property var _map: ({})

    FileView {
        path: Paths.configHome + "/user-dirs.dirs"
        watchChanges: true
        printErrors: false
        onLoaded: root._map = root._parse(text())
        onLoadFailed: root._map = ({})
    }

    function _parse(raw) {
        const map = {};
        const lines = String(raw || "").split("\n");
        for (let i = 0; i < lines.length; i++) {
            const m = lines[i].match(/^XDG_([A-Z]+)_DIR="?([^"]*)"?/);
            if (!m)
                continue;
            let p = String(m[2] || "");
            p = p.replace("${HOME}", root.home).replace("$HOME", root.home);
            if (p.length)
                map[m[1]] = p;
        }
        return map;
    }

    function _dir(key, fallback) {
        const env = Quickshell.env("XDG_" + key + "_DIR");
        if (env && env.length > 0 && env !== root.home)
            return env.replace("${HOME}", root.home).replace("$HOME", root.home);
        const v = root._map[key] || "";
        if (v.length > 0 && v !== root.home)
            return v;
        return root.home + "/" + fallback;
    }

    function expand(p) {
        const s = String(p || "").trim();
        if (s === "~")
            return root.home;
        if (s.indexOf("~/") === 0)
            return root.home + s.slice(1);
        return s;
    }

    function toTilde(p) {
        const s = String(p || "");
        if (s === root.home)
            return "~";
        if (root.home.length > 0 && s.indexOf(root.home + "/") === 0)
            return "~" + s.slice(root.home.length);
        return s;
    }

    function isStockStills(p) {
        const e = expand(p);
        return !String(p || "").length
            || String(p) === "~/Pictures/Screenshots"
            || e === root.home + "/Pictures/Screenshots";
    }

    function isStockRecordings(p) {
        const e = expand(p);
        return !String(p || "").length
            || String(p) === "~/Videos/Recordings"
            || e === root.home + "/Videos/Recordings";
    }

    function resolveStills(p) {
        if (isStockStills(p))
            return pictures + "/Screenshots";
        return expand(p);
    }

    function resolveRecordings(p) {
        if (isStockRecordings(p))
            return videos + "/Recordings";
        return expand(p);
    }
}
