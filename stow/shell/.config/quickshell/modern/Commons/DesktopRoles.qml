// Freedesktop category/name matchers for default-app picks.
// Apps.qml owns DesktopEntries; this file has no I/O.
pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    function matches(role: string, cats: var, name: string, generic: string, id: string, keep: var): bool {
        const stem = String(id || "").replace(/\.desktop$/, "").toLowerCase();
        if (keep && keep[stem])
            return true;
        const list = root._lower(cats);
        if (root._blocked(role, list, stem))
            return false;
        if (root._catMatch(role, list))
            return true;
        return root._nameMatch(role, stem, name, generic);
    }

    function _lower(cats: var): var {
        const src = cats || [];
        const out = [];
        for (let i = 0; i < src.length; i++)
            out.push(String(src[i] || "").toLowerCase());
        return out;
    }

    function _has(list: var, name: string): bool {
        return list.indexOf(name) !== -1;
    }

    function _blocked(role: string, cats: var, stem: string): bool {
        if (role === "communication" && stem.indexOf("kdeconnect") !== -1)
            return true;
        if (role === "textEditor" && root._has(cats, "ide"))
            return true;
        if (role === "imageViewer" && (root._has(cats, "office") || root._has(cats, "vectorgraphics")))
            return true;
        if (role === "videoPlayer" && (root._has(cats, "audiovideoediting") || root._has(cats, "music")))
            return true;
        return false;
    }

    function _catMatch(role: string, cats: var): bool {
        if (role === "browser")
            return root._has(cats, "webbrowser");
        if (role === "calendar")
            return root._has(cats, "calendar") || root._has(cats, "officecalendar");
        if (role === "mail")
            return root._has(cats, "email") || root._has(cats, "officeemail");
        if (role === "communication")
            return root._has(cats, "instantmessaging") || root._has(cats, "chat")
                || root._has(cats, "videoconference");
        if (role === "fileManager")
            return root._has(cats, "filemanager");
        if (role === "videoPlayer")
            return root._has(cats, "video") && root._has(cats, "player");
        if (role === "imageViewer")
            return root._has(cats, "viewer") && root._has(cats, "graphics");
        if (role === "terminal")
            return root._has(cats, "terminalemulator");
        if (role === "textEditor")
            return root._has(cats, "texteditor");
        return false;
    }

    function _nameMatch(role: string, stem: string, name: string, generic: string): bool {
        const needles = root._needles(role);
        const words = (String(name || "") + " " + String(generic || "")).toLowerCase()
            .split(/[^a-z0-9]+/).filter(s => s.length > 0);
        for (let i = 0; i < needles.length; i++) {
            const n = needles[i];
            if (root._stemHit(stem, n) || words.indexOf(n) !== -1)
                return true;
        }
        return false;
    }

    function _stemHit(stem: string, needle: string): bool {
        if (stem === needle || stem.endsWith("." + needle))
            return true;
        if (stem === needle + "-stable" || stem === needle + "-browser"
            || stem === needle + "-esr" || stem === needle + "-beta")
            return true;
        return stem.startsWith(needle + ".");
    }

    function _needles(role: string): var {
        if (role === "browser")
            return ["vivaldi", "firefox", "librewolf", "chromium", "chrome", "brave", "qutebrowser"];
        if (role === "calendar")
            return ["calendar", "kalendar", "korganizer"];
        if (role === "mail")
            return ["mail", "thunderbird", "evolution", "geary", "betterbird"];
        if (role === "communication")
            return ["discord", "telegram", "signal", "whatsapp", "element", "slack", "zoom", "teams"];
        if (role === "fileManager")
            return ["modern.files", "dolphin", "nautilus", "thunar", "nemo", "pcmanfm", "krusader", "caja"];
        if (role === "videoPlayer")
            return ["mpv", "vlc", "celluloid", "haruna", "smplayer", "totem"];
        if (role === "imageViewer")
            return ["imv", "gwenview", "eog", "eom", "loupe", "nsxiv", "feh", "qimgv"];
        if (role === "terminal")
            return ["kitty", "alacritty", "foot", "wezterm", "konsole", "ghostty", "ptyxis"];
        if (role === "textEditor")
            return ["gedit", "gnome-text-editor", "kate", "kwrite", "mousepad", "xed", "pluma", "featherpad"];
        return [];
    }
}
