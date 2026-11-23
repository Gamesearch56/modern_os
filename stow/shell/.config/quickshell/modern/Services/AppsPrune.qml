pragma Singleton

import Quickshell
import QtQuick
import "../Commons"

// A desktop file that disappears, from the app store or any other way,
// has to leave every list that remembered its id. Quickshell reports an
// empty scan before the directories are read; pruning that would clear
// every pin, so an empty scan is ignored. `rev` is what the grids bind,
// because DesktopEntries.applications itself never changes.

Singleton {
    id: root

    property int rev: 0

    function _stem(id: string): string {
        return String(id || "").replace(/\.desktop$/i, "").toLowerCase();
    }

    function _present(): var {
        const entries = DesktopEntries.applications.values || [];
        const have = {};
        for (let i = 0; i < entries.length; i++) {
            const stem = root._stem(entries[i] && entries[i].id);
            if (stem.length)
                have[stem] = true;
        }
        const extra = DesktopShortcuts.shortcuts || [];
        for (let j = 0; j < extra.length; j++) {
            const stem = root._stem(extra[j] && extra[j].id);
            if (stem.length)
                have[stem] = true;
        }
        return have;
    }

    // Shell windows have no desktop file of their own.
    function _known(id: string, have: var): bool {
        if (String(id || "").indexOf("shell:") === 0)
            return true;
        return !!have[root._stem(id)];
    }

    function _keep(list: var, have: var): var {
        const next = [];
        let dropped = 0;
        const raw = list || [];
        for (let i = 0; i < raw.length; i++) {
            const id = String(raw[i] || "");
            if (!id.length)
                continue;
            if (root._known(id, have))
                next.push(id);
            else
                dropped += 1;
        }
        return { next: next, dropped: dropped };
    }

    function prune() {
        // The desktop-folder scan is async. Pruning before it finishes
        // would drop a pin whose .desktop is not in applications/.
        // An empty DesktopEntries list is the scan that has not started,
        // not an empty system, so shortcut ids must not make it look full.
        if (!DesktopShortcuts.ready)
            return;
        const entries = DesktopEntries.applications.values || [];
        if (entries.length === 0)
            return;
        const have = root._present();
        if (Object.keys(have).length === 0)
            return;
        const dock = root._keep(Dock.apps(), have);
        if (dock.dropped > 0)
            ConfigWrite.set("dock.apps", dock.next);
        const start = root._keep(Config.general ? Config.general.autostart : [], have);
        if (start.dropped > 0)
            ConfigWrite.set("general.autostart", start.next);
        root._defaults(have);
        Launcher.dropMissing(have);
        root.rev += 1;
    }

    function _defaults(have: var) {
        const d = (Config.apps && Config.apps.defaults) || ({});
        const roles = ["browser", "calendar", "mail", "communication", "fileManager",
            "videoPlayer", "imageViewer", "textEditor", "terminal"];
        for (let i = 0; i < roles.length; i++) {
            const cur = String(d[roles[i]] || "");
            if (cur.length > 0 && !root._known(cur, have))
                ConfigWrite.set("apps.defaults." + roles[i], "");
        }
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { root.prune(); }
    }

    Connections {
        target: DesktopShortcuts
        function onRevisionChanged() { root.prune(); }
    }

    Component.onCompleted: root.prune()
}
