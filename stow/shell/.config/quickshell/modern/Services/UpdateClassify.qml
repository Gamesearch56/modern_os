// Pacman row icons and system-vs-other split for Settings → Update.
import QtQuick
import "../Commons"

QtObject {
    id: root

    function icon(name: string): string {
        const n = String(name || "");
        if (n.indexOf("linux") === 0)
            return "cpu";
        if (n.indexOf("hypr") !== -1 || n.indexOf("quickshell") === 0)
            return "preferences-desktop-display";
        if (n === "nautilus" || n === "dolphin")
            return "system-file-manager";
        if (n === "kitty")
            return "utilities-terminal";
        return n === "vivaldi" ? "web-browser" : "package-x-generic-symbolic";
    }

    function stem(id: string): string {
        return String(id || "").replace(/\.desktop$/i, "").replace(/^org\.kde\./, "").replace(/^org\.gnome\./, "").replace(/-stable$/, "").toLowerCase();
    }

    function isSystem(name: string): bool {
        const n = String(name || "");
        if (/^(linux|mesa|nvidia|wayland|wlroots)/.test(n) || n.indexOf("hypr") !== -1 || n.indexOf("quickshell") === 0)
            return true;
        const defs = Config.apps.defaults || {};
        const stems = [root.stem(defs.browser), root.stem(defs.fileManager), root.stem(defs.terminal)];
        for (let i = 0; i < stems.length; i++) {
            if (stems[i].length && (n === stems[i] || n.indexOf(stems[i] + "-") === 0))
                return true;
        }
        return "pipewire wireplumber systemd greetd grim slurp matugen pacman reflector bluez networkmanager polkit stow qt6-base qt6-declarative kitty nautilus vivaldi".split(" ").indexOf(n) !== -1;
    }

    function parseCheck(text: string) {
        const all = [];
        const sys = [];
        const other = [];
        const lines = String(text || "").trim().split("\n");
        for (let i = 0; i < lines.length; i++) {
            const m = lines[i].match(/^(\S+)\s+(\S+)\s+->\s+(\S+)/);
            if (!m)
                continue;
            const row = { name: m[1], from: m[2], to: m[3], iconName: root.icon(m[1]) };
            all.push(row);
            if (root.isSystem(m[1]))
                sys.push(row);
            else
                other.push(row);
        }
        return { all: all, sys: sys, other: other };
    }

    function parseDesktop(text: string) {
        let data = {};
        try {
            data = JSON.parse(String(text || "").trim() || "{}");
        } catch (e) {
            data = { pending: false, reason: "unavailable" };
        }
        const from = String(data.from || "");
        const to = String(data.to || "");
        const pending = data.pending === true;
        const reason = String(data.reason || "");
        let subtitle = I18n.t("settings.update.desktopCurrent");
        if ("unavailable offline dirty notag".split(" ").indexOf(reason) !== -1)
            subtitle = I18n.t("settings.update.desktopUnavailable");
        else if (pending && from.length && to.length)
            subtitle = I18n.t("settings.update.fromTo", ({ from: from, to: to }));
        return {
            kind: "desktop",
            name: I18n.t("settings.update.desktop"),
            from: from,
            to: to,
            pending: pending,
            iconName: "",
            iconSource: Paths.brandLogo,
            subtitle: subtitle
        };
    }

    function rebuild(desk, pacmanAll, pacmanSys, pacmanOther) {
        const card = {
            kind: "desktop",
            name: String(desk.name || I18n.t("settings.update.desktop")),
            from: desk.from,
            to: desk.to,
            pending: desk.pending === true,
            iconName: desk.iconName || "",
            iconSource: desk.iconSource || Paths.brandLogo,
            subtitle: desk.subtitle || I18n.t("settings.update.desktopCurrent")
        };
        const all = [];
        if (card.pending)
            all.push(card);
        for (let i = 0; i < pacmanAll.length; i++)
            all.push(pacmanAll[i]);
        return { systemPkgs: [card].concat(pacmanSys), otherPkgs: pacmanOther, pending: all };
    }
}
