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
        const configured = root._entryById(root.desktopId(role));
        if (configured)
            return configured;
        return root._entryFromIds(root._fallbackIds(role));
    }

    function launch(role: string): bool {
        try {
            const e = root.entryFor(role);
            if (e?.execute) {
                e.execute();
                return true;
            }
            const fallback = root._fallback(role);
            if (fallback) {
                Quickshell.execDetached(fallback);
                return true;
            }
            Logger.warn("Apps", "no desktop entry for role " + role);
            return false;
        } catch (err) {
            Logger.error("Apps", String(err));
            return false;
        }
    }

    function _entryById(id: string): var {
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

    function _entryFromIds(ids: var): var {
        const list = ids || [];
        for (let i = 0; i < list.length; i++) {
            const e = root._entryById(list[i]);
            if (e)
                return e;
        }
        return null;
    }

    function _fallbackIds(role: string): var {
        if (role === "calendar")
            return ["gnome-calendar.desktop", "org.gnome.Calendar.desktop", "kalendar.desktop", "org.kde.kalendar.desktop", "org.kde.korganizer.desktop"];
        return [];
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

    function openFolder(dir: string): bool {
        try {
            if (!dir || dir.length === 0)
                return false;
            Quickshell.execDetached(["mkdir", "-p", dir]);
            const id = String(root.desktopId("fileManager") || "").replace(/\.desktop$/, "");
            const lower = id.toLowerCase();
            if (lower.indexOf("dolphin") !== -1) {
                Quickshell.execDetached(["dolphin", "--new-window", dir]);
                return true;
            }
            if (lower.indexOf("nautilus") !== -1) {
                Quickshell.execDetached(["nautilus", dir]);
                return true;
            }
            if (lower.indexOf("thunar") !== -1) {
                Quickshell.execDetached(["thunar", dir]);
                return true;
            }
            if (lower.indexOf("nemo") !== -1) {
                Quickshell.execDetached(["nemo", dir]);
                return true;
            }
            if (id.length > 0) {
                Quickshell.execDetached(["gtk-launch", id, dir]);
                return true;
            }
            const fb = root._fallback("fileManager");
            if (fb) {
                Quickshell.execDetached(fb.concat([dir]));
                return true;
            }
            Quickshell.execDetached(["xdg-open", dir]);
            return true;
        } catch (err) {
            Logger.error("Apps", String(err));
            return false;
        }
    }
}
