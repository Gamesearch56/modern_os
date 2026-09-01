// Default-app launcher. Roles come from config apps.defaults
// (browser, calendar, mail, communication, fileManager, videoPlayer,
// imageViewer, terminal).
// DesktopEntries lookup lives here so Modules never spawn processes.
pragma Singleton

import Quickshell
import QtQuick
import "../Commons"
import "fileManager.js" as FileManager

Singleton {
    id: root

    readonly property var defaults: Config.apps?.defaults ?? ({})

    function allEntries(): var {
        return root._list("");
    }

    function entriesFor(role: string): var {
        return root._list(role || "");
    }

    function _stem(id: string): string {
        return String(id || "").replace(/\.desktop$/, "").toLowerCase();
    }

    function _list(role: string): var {
        const entries = DesktopEntries.applications.values;
        const keep = {};
        if (role.length > 0) {
            const cur = root.desktopId(role);
            if (cur)
                keep[root._stem(cur)] = cur;
            const fb = root._fallbackIds(role) || [];
            for (let i = 0; i < fb.length; i++) {
                const stem = root._stem(fb[i]);
                if (stem && keep[stem] === undefined)
                    keep[stem] = fb[i];
            }
        }
        const out = [];
        const seen = {};
        for (let i = 0; i < entries.length; i++) {
            const e = entries[i];
            const stem = root._stem(e.id || e.name);
            const pinned = !!(keep[stem]);
            // imv.desktop (and similar MIME handlers) ship NoDisplay=true.
            if (e.noDisplay && !pinned)
                continue;
            if (role.length > 0 && !DesktopRoles.matches(role, e.categories, e.name, e.genericName, e.id, keep))
                continue;
            const value = pinned ? (keep[stem] || e.id || e.name) : (e.id || e.name);
            out.push({ value: value, titleValue: e.name || e.id });
            seen[stem] = true;
        }
        const missing = Object.keys(keep);
        for (let j = 0; j < missing.length; j++) {
            const stem = missing[j];
            if (seen[stem])
                continue;
            const id = keep[stem];
            const e = root._entryById(id);
            out.push({
                value: id,
                titleValue: (e && e.name) ? e.name : stem
            });
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

    function displayName(role: string): string {
        const e = root.entryFor(role);
        if (e && e.name)
            return String(e.name);
        const id = root.desktopId(role);
        if (id.length)
            return root.labelForId(id);
        const fb = root._fallbackIds(role) || [];
        if (fb.length)
            return root.labelForId(fb[0]);
        return "";
    }

    function labelForId(id: string): string {
        const e = root._entryById(id);
        if (e?.name)
            return String(e.name);
        return String(id || "").replace(/\.desktop$/, "");
    }

    function iconForId(id: string): string {
        const e = root._entryById(id);
        return e?.icon ? String(e.icon) : "application-x-executable";
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
            return ["proton-calendar.desktop", "proton-calendar", "proton-mail.desktop", "gnome-calendar.desktop", "org.gnome.Calendar.desktop", "kalendar.desktop", "org.kde.kalendar.desktop", "org.kde.korganizer.desktop"];
        if (role === "mail")
            return ["proton-mail.desktop", "proton-mail", "org.proton.Mail.desktop", "thunderbird.desktop", "org.mozilla.Thunderbird.desktop"];
        if (role === "communication")
            return ["whatsapp.desktop", "whatsapp-desktop.desktop", "whatsapp-for-linux.desktop", "com.rtg.whatsapp.desktop", "io.github.mimbrero.WhatsAppDesktop.desktop", "wasistlos.desktop", "zapzap.desktop"];
        if (role === "videoPlayer")
            return ["mpv.desktop", "mpv"];
        if (role === "imageViewer")
            return ["imv.desktop", "imv"];
        return [];
    }

    function _fallback(role: string): var {
        if (role === "browser")
            return ["vivaldi"];
        if (role === "fileManager")
            return ["nautilus"];
        if (role === "terminal")
            return ["kitty"];
        if (role === "videoPlayer")
            return ["mpv"];
        if (role === "imageViewer")
            return ["imv"];
        if (role === "mail")
            return ["xdg-open", "https://mail.proton.me"];
        return null;
    }

    function launchBackground(desktopId: string): bool {
        const name = String(desktopId || "").replace(/\.desktop$/, "");
        if (!name.length)
            return false;
        Quickshell.execDetached([Paths.modernLaunch, "--background", name]);
        return true;
    }

    function runInTerminal(argv: var): bool {
        const args = argv || [];
        if (args.length === 0)
            return false;
        try {
            const id = String(root.desktopId("terminal") || "").replace(/\.desktop$/, "").toLowerCase();
            let cmd = [];
            if (id.indexOf("foot") !== -1)
                cmd = ["foot"].concat(args);
            else if (id.indexOf("alacritty") !== -1)
                cmd = ["alacritty", "-e"].concat(args);
            else if (id.indexOf("wezterm") !== -1)
                cmd = ["wezterm", "start", "--"].concat(args);
            else if (id.indexOf("kitty") !== -1 || id.length === 0)
                cmd = ["kitty", "-e"].concat(args);
            else
                cmd = [id.split(".").pop() || id, "-e"].concat(args);
            Quickshell.execDetached(cmd);
            return true;
        } catch (err) {
            Logger.error("Apps", String(err));
            return false;
        }
    }

    function openFolder(dir: string): bool {
        try {
            if (!dir || dir.length === 0)
                return false;
            Quickshell.execDetached(["mkdir", "-p", dir]);
            Quickshell.execDetached(FileManager.argv(root.desktopId("fileManager"), dir, false));
            return true;
        } catch (err) {
            Logger.error("Apps", String(err));
            return false;
        }
    }

    function openInFileManager(path: string): bool {
        try {
            const p = FileManager.localPath(path);
            if (!p.length)
                return false;
            Quickshell.execDetached(FileManager.argv(root.desktopId("fileManager"), p, true));
            return true;
        } catch (err) {
            Logger.error("Apps", String(err));
            return false;
        }
    }
}
