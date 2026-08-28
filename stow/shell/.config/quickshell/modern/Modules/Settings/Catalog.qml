// Runtime search index mirroring sections/*/section.json.
import QtQuick
import "../../Commons"

QtObject {
    id: root

    readonly property var ids: [
        "general", "users", "power",
        "design", "displays", "windows",
        "widgets", "launcher", "screenshots",
        "applications", "accounts", "privacy",
        "language", "keyboard",
        "audio", "network",
        "storage", "system", "gaming"
    ]

    readonly property var groupOrder: ["session", "appearance", "desktop", "apps", "input", "devices", "system"]

    function icon(id) {
        return root._byId[id]?.icon ?? "preferences-system";
    }

    function order(id) {
        return root._byId[id]?.order ?? 99;
    }

    function group(id) {
        return root._byId[id]?.group ?? "session";
    }

    function keywords(id) {
        return root._byId[id]?.keywords ?? [];
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
        general: { icon: "preferences-system", order: 10, group: "session", keywords: ["idle", "autologin", "animation"] },
        users: { icon: "user-group-new", order: 15, group: "session", keywords: ["accounts", "passwd"] },
        power: { icon: "system-shutdown", order: 18, group: "session", keywords: ["lid", "suspend"] },
        design: { icon: "preferences-desktop-theme", order: 20, group: "appearance", keywords: ["theme", "motion", "tint", "transparency"] },
        displays: { icon: "video-display", order: 25, group: "appearance", keywords: ["monitors", "workspace"] },
        windows: { icon: "preferences-system-windows", order: 28, group: "appearance", keywords: ["titlebar", "rules"] },
        widgets: { icon: "view-grid", order: 30, group: "desktop", keywords: ["bar", "layout"] },
        launcher: { icon: "view-app-grid-symbolic", order: 32, group: "desktop", keywords: ["frecency"] },
        screenshots: { icon: "camera-photo", order: 34, group: "desktop", keywords: ["capture", "grim"] },
        applications: { icon: "applications-other", order: 40, group: "apps", keywords: ["autostart", "browser", "calendar"] },
        accounts: { icon: "system-users", order: 42, group: "apps", keywords: ["proton", "calendar", "ai"] },
        privacy: { icon: "security-high", order: 44, group: "apps", keywords: ["dnd", "kdeconnect"] },
        language: { icon: "preferences-desktop-locale", order: 50, group: "input", keywords: ["locale", "date", "time"] },
        keyboard: { icon: "input-keyboard", order: 52, group: "input", keywords: ["keybinds", "layout"] },
        audio: { icon: "audio-volume-high", order: 60, group: "devices", keywords: ["volume", "bluetooth", "speakers", "headphones", "output"] },
        network: { icon: "network-wireless", order: 62, group: "devices", keywords: ["wifi", "dns"] },
        storage: { icon: "drive-harddisk", order: 70, group: "system", keywords: ["backup", "snapper"] },
        system: { icon: "computer", order: 72, group: "system", keywords: ["diagnostics"] },
        gaming: { icon: "input-gaming", order: 74, group: "system", keywords: ["optiscaler"] }
    })
}
