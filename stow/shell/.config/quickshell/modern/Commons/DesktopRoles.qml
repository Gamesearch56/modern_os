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
        const want = root._cats(role);
        const list = cats || [];
        for (let i = 0; i < list.length; i++) {
            if (want.indexOf(String(list[i]).toLowerCase()) !== -1)
                return true;
        }
        const hay = (String(name || "") + " " + String(generic || "") + " " + stem).toLowerCase();
        const needles = root._needles(role);
        for (let j = 0; j < needles.length; j++) {
            if (hay.indexOf(needles[j]) !== -1)
                return true;
        }
        return false;
    }

    function _cats(role: string): var {
        if (role === "browser")
            return ["webbrowser"];
        if (role === "calendar")
            return ["calendar", "officecalendar"];
        if (role === "mail")
            return ["email", "officeemail"];
        if (role === "communication")
            return ["instantmessaging", "chat", "ircclient", "videoconference", "telephony"];
        if (role === "fileManager")
            return ["filemanager"];
        if (role === "terminal")
            return ["terminalemulator"];
        return [];
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
            return ["dolphin", "nautilus", "thunar", "nemo", "pcmanfm", "krusader", "caja"];
        if (role === "terminal")
            return ["kitty", "alacritty", "foot", "wezterm", "konsole", "ghostty", "ptyxis"];
        return [];
    }
}
