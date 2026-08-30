// Runtime search index mirroring sections/*/section.json.
import QtQuick
import "../../Commons"

QtObject {
    id: root

    readonly property var ids: [
        "overview", "users", "privacy", "power",
        "design", "bar", "launcher",
        "applications", "screenshots", "ai",
        "language", "keyboard",
        "displays", "audio", "network", "bluetooth",
        "storage", "backup", "system"
    ]

    readonly property var groupOrder: [
        "general", "appearance", "apps", "input", "devices", "system"
    ]

    function icon(id) {
        return root._byId[id]?.icon ?? "preferences-system";
    }

    function order(id) {
        return root._byId[id]?.order ?? 99;
    }

    function group(id) {
        return root._byId[id]?.group ?? "general";
    }

    function keywords(id) {
        return root._byId[id]?.keywords ?? [];
    }

    function restorePaths(id) {
        return root._byId[id]?.restore ?? [];
    }

    function filtered(needle) {
        const n = (needle || "").trim().toLowerCase();
        const items = [];
        for (let i = 0; i < root.ids.length; i++) {
            const id = root.ids[i];
            if (n.length === 0 || root._matches(id, n))
                items.push(id);
        }
        items.sort((a, b) => root.order(a) - root.order(b));
        const out = [];
        let lastGroup = "";
        for (let j = 0; j < items.length; j++) {
            const id = items[j];
            const g = root.group(id);
            if (g !== lastGroup) {
                out.push({ kind: "group", id: g, key: "settings.nav." + g });
                lastGroup = g;
            }
            out.push({ kind: "item", id: id });
        }
        return out;
    }

    function _matches(id, n) {
        const title = I18n.t("settings.sections." + id).toLowerCase();
        if (title.indexOf(n) !== -1)
            return true;
        const kws = root.keywords(id);
        for (let i = 0; i < kws.length; i++) {
            if (String(kws[i]).toLowerCase().indexOf(n) !== -1)
                return true;
        }
        return false;
    }

    readonly property var _byId: ({
        overview: { icon: "view-pages-overview", order: 10, group: "general", keywords: ["about", "hardware", "software", "boot", "stats"] },
        users: { icon: "user-identity", order: 12, group: "general", keywords: ["accounts", "passwd", "autologin"] },
        privacy: { icon: "security-high", order: 14, group: "general", keywords: ["dnd", "kdeconnect", "calendar", "ics", "quiet", "notifications"], restore: ["general.dndSchedule", "general.notificationTimeoutMs", "kdeconnect", "accounts.calendarIcsUrl"] },
        power: { icon: "battery", order: 16, group: "general", keywords: ["lid", "suspend", "energy", "idle", "battery"], restore: ["power", "general.idleTimings"] },
        design: { icon: "preferences-desktop-theme", order: 20, group: "appearance", keywords: ["theme", "motion", "wallpaper", "windows", "gaps", "cursor"], restore: ["design", "typography", "motion", "windows", "windowRules"] },
        bar: { icon: "cs-panel", order: 22, group: "appearance", keywords: ["widgets", "layout", "topbar"], restore: ["bar", "widgets"] },
        launcher: { icon: "view-app-grid-symbolic", order: 24, group: "appearance", keywords: ["frecency", "icons", "results", "search"], restore: ["launcher"] },
        applications: { icon: "applications-other", order: 30, group: "apps", keywords: ["autostart", "browser", "calendar", "mail", "messenger"], restore: ["apps.defaults", "general.autostart"] },
        screenshots: { icon: "camera-photo", order: 32, group: "apps", keywords: ["capture", "grim", "png", "jpeg", "webp", "clipboard"], restore: ["screenshots"] },
        ai: { icon: "robot", order: 34, group: "apps", keywords: ["ollama", "assistant"] },
        language: { icon: "preferences-desktop-locale", order: 40, group: "input", keywords: ["locale", "date", "time", "timezone"], restore: ["language", "widgets.clock.showWeekday", "widgets.clock.showSeconds"] },
        keyboard: { icon: "input-keyboard", order: 42, group: "input", keywords: ["keybinds", "layout", "cheatsheet"], restore: ["input", "keybinds"] },
        displays: { icon: "video-display", order: 50, group: "devices", keywords: ["monitors", "workspace", "hdr", "scale", "display"] },
        audio: { icon: "audio-volume-high", order: 52, group: "devices", keywords: ["volume", "speakers", "microphone"] },
        network: { icon: "network-wireless", order: 54, group: "devices", keywords: ["wifi", "dns", "vpn", "speed"] },
        bluetooth: { icon: "bluetooth", order: 56, group: "devices", keywords: ["devices", "pair"] },
        storage: { icon: "drive-harddisk", order: 70, group: "system", keywords: ["disk", "mount"] },
        backup: { icon: "document-save", order: 72, group: "system", keywords: ["snapper", "snapshot", "restore"] },
        system: { icon: "system-software-update", order: 74, group: "system", keywords: ["update", "mirrors", "gaming"] }
    })
}
