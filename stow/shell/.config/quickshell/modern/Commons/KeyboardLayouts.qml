// Shared XKB catalog with the live installer. File is the same list
// iso/releng/installer-locales.json `layouts` keeps — Settings must not
// invent a second set. Default stays us until the user picks another.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property var _ids: ["us"]

    readonly property var ids: root._ids.length > 0 ? root._ids : ["us"]

    readonly property var options: {
        const list = root.ids;
        const out = [];
        for (let i = 0; i < list.length; i++) {
            const id = String(list[i] || "");
            if (id.length === 0)
                continue;
            out.push({ value: id, titleKey: "settings.kbLayouts." + id });
        }
        return out;
    }

    FileView {
        path: `${Paths.configHome}/modern/keyboard-layouts.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const data = JSON.parse(text());
                const listed = data.layouts || [];
                root._ids = listed.length > 0 ? listed : ["us"];
            } catch (e) {
                root._ids = ["us"];
            }
        }
        onLoadFailed: root._ids = ["us"]
    }
}
