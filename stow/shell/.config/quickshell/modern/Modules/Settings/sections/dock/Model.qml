import QtQuick
import "../../../../Commons"
import "../../../../Services"

QtObject {
    id: root

    readonly property var pins: {
        void Config.generation;
        return Dock.apps();
    }

    readonly property var installed: {
        void Config.generation;
        void DesktopShortcuts.revision;
        void I18n.t("settings.title");
        // Pinned ids stay in this grid. Removing them reflows the view
        // and jumps the scroll position the moment a pin is added.
        const shell = [
            { id: "shell:settings", name: I18n.t("settings.title"), icon: "modern-settings-symbolic" },
            { id: "shell:store", name: I18n.t("store.title"), icon: "modern-store-symbolic" },
            { id: "shell:files", name: I18n.t("files.launcherName"), icon: "modern-files-symbolic" }
        ];
        const out = [];
        for (let s = 0; s < shell.length; s++)
            out.push(shell[s]);
        const apps = Launcher.catalog("");
        for (let a = 0; a < apps.length; a++) {
            const id = String(apps[a].id || "");
            if (!id.length || id.replace(/\.desktop$/i, "") === "modern.files")
                continue;
            out.push({ id: id, name: String(apps[a].name || Dock.labelFor(id)), icon: String(apps[a].icon || "") });
        }
        return out;
    }
}
