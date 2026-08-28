// Default-app launcher. Roles come from config apps.defaults
// (browser, calendar, fileManager, terminal). DesktopEntries lookup
// lives here so Modules never spawn processes.
pragma Singleton

import Quickshell
import QtQuick
import "../Commons"

Singleton {
    id: root

    readonly property var defaults: Config.apps?.defaults ?? ({})

    function allEntries(): var {
        const entries = DesktopEntries.applications.values;
        const out = [];
        for (let i = 0; i < entries.length; i++) {
            const e = entries[i];
            if (e.noDisplay)
                continue;
            out.push({ value: e.id || e.name, titleValue: e.name || e.id });
        }
        out.sort((a, b) => a.titleValue.localeCompare(b.titleValue));
        return out;
    }

    function desktopId(role: string): string {
        const d = root.defaults || ({});
        return d[role] || "";
    }

    function entryFor(role: string): var {
        const id = root.desktopId(role);
        if (!id)
            return null;
        const entries = DesktopEntries.applications.values;
        const needle = id.replace(/\.desktop$/, "").toLowerCase();
        for (let i = 0; i < entries.length; i++) {
            const e = entries[i];
            const eid = String(e.id || "").replace(/\.desktop$/, "").toLowerCase();
            if (eid === needle || String(e.id || "") === id)
                return e;
        }
        return null;
    }

    function launch(role: string) {
        try {
            const e = root.entryFor(role);
            if (e?.execute) {
                e.execute();
                return;
            }
            const fallback = root._fallback(role);
            if (fallback)
                Quickshell.execDetached(fallback);
            else
                Logger.warn("Apps", "no desktop entry for role " + role);
        } catch (err) {
            Logger.error("Apps", String(err));
        }
    }

    function _fallback(role: string): var {
        if (role === "browser")
            return ["vivaldi"];
        if (role === "fileManager")
            return ["dolphin"];
        if (role === "terminal")
            return ["kitty"];
        return null;
    }
}
