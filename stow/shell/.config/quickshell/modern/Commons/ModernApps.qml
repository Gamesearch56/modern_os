pragma Singleton

import Quickshell
import QtQuick

// This desktop's own applications that ship a .desktop file. Name= is
// the full product name ("ModernOS Texteditor"), which Settings lists;
// the launcher, dock, and window cards use the short name instead.
// A new app adds one row here.
Singleton {
    id: root

    readonly property var _apps: ({
        "modern.files": { nameKey: "files.launcherName", icon: "modern-files" },
        "modern.editor": { nameKey: "editor.launcherName", icon: "modern-editor" },
        "modern.imageviewer": { nameKey: "viewer.launcherName", icon: "modern-imageviewer" },
        "modern.mediaplayer": { nameKey: "player.launcherName", icon: "modern-mediaplayer" },
        "modern.manual": { nameKey: "manual.launcherName", icon: "modern-manual" },
        "modern.wallpaper": { nameKey: "wallpaper.launcherName", icon: "modern-wallpaper" },
        "modern.cheatsheet": { nameKey: "cheatsheet.launcherName", icon: "modern-cheatsheet" },
        "modern.bugreport": { nameKey: "bugReport.launcherName", icon: "modern-bugreport" }
    })

    function _key(raw: string): string {
        return String(raw || "").trim().toLowerCase().replace(/\.desktop$/i, "");
    }

    function owns(raw: string): bool {
        return root._apps[root._key(raw)] !== undefined;
    }

    // Desktop id, desktop id without .desktop, or a window class.
    function shortName(raw: string): string {
        const app = root._apps[root._key(raw)];
        return app ? I18n.t(app.nameKey) : "";
    }

    function icon(raw: string): string {
        const app = root._apps[root._key(raw)];
        return app ? app.icon : "";
    }
}
