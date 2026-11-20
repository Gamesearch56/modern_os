pragma Singleton

import Quickshell
import QtQuick

// One icon family for the shell's own applications. Callers pass a
// desktop id, a window title, or a theme name; the glyph is always the
// symbolic mark so the plate can take the current theme color.
Singleton {
    id: root

    function glyph(raw: string): string {
        const s = String(raw || "").trim().toLowerCase().replace(/\.desktop$/i, "");
        if (!s.length)
            return "";
        if (s === "shell:settings" || s === "modern.settings" || s === "modern-settings"
                || s === "modern-settings-symbolic" || s === "systemsettings")
            return "modern-settings-symbolic";
        if (s === "shell:store" || s === "modern.store" || s === "modern-store"
                || s === "modern-store-symbolic" || s === "plasmadiscover")
            return "modern-store-symbolic";
        if (s === "shell:files" || s === "modern.files" || s === "modern-files"
                || s === "modern-files-symbolic")
            return "modern-files-symbolic";
        if (s === "modern.wallpaper" || s === "modern-wallpaper" || s === "modern-wallpaper-symbolic")
            return "modern-wallpaper-symbolic";
        if (s === "modern.cheatsheet" || s === "modern-cheatsheet" || s === "modern-cheatsheet-symbolic")
            return "modern-cheatsheet-symbolic";
        if (s === "modern.bugreport" || s === "modern-bugreport" || s === "modern-bugreport-symbolic")
            return "modern-bugreport-symbolic";
        // The default browser joins the same plate. App windows keep their own marks.
        if (s === "vivaldi" || s === "vivaldi-stable" || s === "vivaldi-bin"
                || s === "modern-vivaldi" || s === "modern-vivaldi-symbolic")
            return "modern-vivaldi-symbolic";
        return "";
    }
}
