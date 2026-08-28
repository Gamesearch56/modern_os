// Runtime search index mirroring sections/*/section.json. Modules cannot
// FileView those descriptors, so this QtObject is the in-process copy
// Settings search filters against. Keep keywords in sync with section.json.
import QtQuick
import "../../Commons"

QtObject {
    id: root

    readonly property var ids: [
        "general", "applications", "accounts", "privacy", "design",
        "language", "keyboard", "time", "displays", "windows",
        "audio", "network", "widgets", "launcher", "power",
        "screenshots", "users", "storage", "system", "gaming"
    ]

    function icon(id) {
        return root._byId[id]?.icon ?? "preferences-system";
    }

    function order(id) {
        return root._byId[id]?.order ?? 99;
    }

    function keywords(id) {
        return root._byId[id]?.keywords ?? [];
    }

    function filtered(needle) {
        const n = (needle || "").trim().toLowerCase();
        const out = [];
        for (let i = 0; i < root.ids.length; i++) {
            const id = root.ids[i];
            if (n.length === 0 || root._matches(id, n))
                out.push(id);
        }
        out.sort((a, b) => root.order(a) - root.order(b));
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
        general: { icon: "preferences-system", order: 10, keywords: ["motion", "scale", "idle", "dnd", "autologin", "animation"] },
        applications: { icon: "applications-other", order: 20, keywords: ["autostart", "apps", "startup"] },
        accounts: { icon: "system-users", order: 30, keywords: ["proton", "calendar", "ai", "ollama", "kdeconnect"] },
        privacy: { icon: "security-high", order: 40, keywords: ["permissions", "kdeconnect", "clipboard", "notifications", "dnd"] },
        design: { icon: "preferences-desktop-theme", order: 50, keywords: ["theme", "profile", "transparency", "rounding", "cursor"] },
        language: { icon: "preferences-desktop-locale", order: 60, keywords: ["locale", "ui", "translation", "english", "german"] },
        keyboard: { icon: "input-keyboard", order: 70, keywords: ["keybinds", "shortcuts", "hotkeys", "cheatsheet"] },
        time: { icon: "preferences-system-time", order: 80, keywords: ["clock", "date", "format", "timezone", "weekday"] },
        displays: { icon: "video-display", order: 90, keywords: ["monitors", "scale", "resolution", "profile"] },
        windows: { icon: "preferences-system-windows", order: 100, keywords: ["rules", "floating", "opacity", "workspace"] },
        audio: { icon: "audio-volume-high", order: 110, keywords: ["volume", "limit", "bluetooth", "pipewire"] },
        network: { icon: "network-wireless", order: 120, keywords: ["wifi", "dns", "ethernet"] },
        widgets: { icon: "view-grid", order: 130, keywords: ["bar", "layout", "left", "center", "right"] },
        launcher: { icon: "view-app-grid-symbolic", order: 140, keywords: ["frecency", "providers", "prefix", "search"] },
        power: { icon: "system-shutdown", order: 150, keywords: ["lid", "suspend", "inhibit", "button"] },
        screenshots: { icon: "camera-photo", order: 160, keywords: ["capture", "png", "clipboard", "grim"] },
        users: { icon: "user-group-new", order: 170, keywords: ["accounts", "passwd", "groups", "modern-usersd"] },
        storage: { icon: "drive-harddisk", order: 180, keywords: ["backup", "snapper", "restic", "snapshot"] },
        system: { icon: "computer", order: 190, keywords: ["diagnostics", "boot", "journal", "logs"] },
        gaming: { icon: "input-gaming", order: 200, keywords: ["optiscaler", "game", "vm", "limits"] }
    })
}
