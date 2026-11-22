// UI languages from languages.json, the catalog the ISO installer builds
// its Welcome, locale and keyboard defaults from. One entry per
// translations/<id>.json, so Settings never offers a language the shell
// cannot show and never misses one the installer offered.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property var _ids: []

    readonly property var ids: {
        const out = root._ids.length > 0 ? root._ids.slice() : ["en"];
        const current = String(Config.language.ui || "");
        if (current.length > 0 && out.indexOf(current) < 0)
            out.push(current);
        return out;
    }

    readonly property var options: root.ids.map(id => ({ value: id, titleKey: "settings.langs." + id }))

    FileView {
        path: `${Paths.configHome}/modern/languages.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const rows = JSON.parse(text()).languages || [];
                root._ids = rows.map(r => String(r.id || "")).filter(id => id.length > 0);
            } catch (e) {
                root._ids = [];
            }
        }
        onLoadFailed: (error) => {
            Logger.warn("Languages", `languages.json not loaded (${error}); only the fallback language is offered`);
            root._ids = [];
        }
    }
}
