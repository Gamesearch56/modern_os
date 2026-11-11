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
        if (n === "mpv")
            return "applications-multimedia";
        if (n === "imv")
            return "image-x-generic";
        if (n === "neovim")
            return "accessories-text-editor";
        return n === "vivaldi" ? "web-browser" : "package-x-generic-symbolic";
    }

    // A desktop release already showed its own progress overlay, so a
    // run that carried one stays quiet here.
    function doneSummary(ran): string {
        const list = ran || [];
        if (list.some(p => String(p && p.kind || "") === "desktop"))
            return "";
        if (list.length === 1 && String(list[0] && list[0].kind || "") === "boot")
            return I18n.t("settings.update.bootRepaired");
        if (list.length === 1)
            return I18n.t("settings.update.packageDone");
        return list.length > 1
            ? I18n.t("settings.update.packagesDone", ({ n: String(list.length) }))
            : I18n.t("settings.update.success");
    }

    // A desktop release replaces the package count. The version is the
    // pending card's `to` field from desktop-sync.
    function availableNotice(pending): string {
        const list = pending || [];
        for (let i = 0; i < list.length; i++) {
            const p = list[i];
            if (String(p && p.kind || "") === "desktop" && String(p && p.to || "").length)
                return I18n.t("settings.update.desktopAvailable", ({ v: String(p.to) }));
        }
        return I18n.t("settings.update.available", ({ n: String(list.length) }));
    }

    function stem(id: string): string {
        return String(id || "").replace(/\.desktop$/i, "").replace(/^org\.kde\./, "").replace(/^org\.gnome\./, "").replace(/-stable$/, "").toLowerCase();
    }

    function isSystem(name: string, shipped): bool {
        const n = String(name || "");
        if (shipped && shipped[n])
            return true;
        if (/^(linux|mesa|nvidia|wayland|wlroots)/.test(n) || n.indexOf("hypr") !== -1 || n.indexOf("quickshell") === 0)
            return true;
        const defs = Config.apps.defaults || {};
        const stems = [
            root.stem(defs.browser),
            root.stem(defs.fileManager),
            root.stem(defs.terminal),
            root.stem(defs.videoPlayer),
            root.stem(defs.imageViewer),
            root.stem(defs.textEditor)
        ];
        for (let i = 0; i < stems.length; i++) {
            if (stems[i].length && (n === stems[i] || n.indexOf(stems[i] + "-") === 0))
                return true;
        }
        return "pipewire wireplumber systemd greetd grim slurp matugen matugen-bin cliphist pacman reflector bluez networkmanager polkit stow qt6-base qt6-declarative kitty nautilus vivaldi mpv imv neovim".split(" ").indexOf(n) !== -1;
    }

    function parseCheck(text: string, shipped) {
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
            if (root.isSystem(m[1], shipped))
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
        if (reason === "notag")
            subtitle = I18n.t("settings.update.desktopUnknown");
        else if ("unavailable offline dirty".split(" ").indexOf(reason) !== -1)
            subtitle = I18n.t("settings.update.desktopUnavailable");
        else if (pending && from.length && to.length)
            subtitle = I18n.t("settings.update.fromTo", ({ from: from, to: to }));
        return {
            kind: "desktop",
            name: I18n.t("settings.update.desktop"),
            from: from,
            to: to,
            pending: pending,
            reason: reason,
            iconName: "",
            iconSource: Paths.brandLogo,
            subtitle: subtitle,
            bootRepair: data.bootRepair === true
        };
    }

    function rebuild(desk, pacmanAll, pacmanSys, pacmanOther) {
        const card = {
            kind: "desktop",
            name: String(desk.name || I18n.t("settings.update.desktop")),
            from: desk.from,
            to: desk.to,
            pending: desk.pending === true,
            reason: String(desk.reason || ""),
            iconName: desk.iconName || "",
            iconSource: desk.iconSource || Paths.brandLogo,
            subtitle: desk.subtitle || I18n.t("settings.update.desktopCurrent"),
            bootRepair: desk.bootRepair === true
        };
        const boot = card.bootRepair ? [{
            kind: "boot",
            name: I18n.t("settings.update.bootRepair"),
            from: "",
            to: "",
            iconName: "cpu",
            subtitle: I18n.t("settings.update.bootRepairBody")
        }] : [];
        const all = boot.slice();
        if (card.pending)
            all.push(card);
        for (let i = 0; i < pacmanAll.length; i++)
            all.push(pacmanAll[i]);
        const sys = boot.concat(card.pending ? [card].concat(pacmanSys) : pacmanSys);
        return { systemPkgs: sys, otherPkgs: pacmanOther, pending: all };
    }
}
