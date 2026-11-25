// Which screen the assistant panel belongs to.
import Quickshell
import QtQuick
import "../Commons"

Item {
    function covers(screen: var, open: bool, host: string): bool {
        if (!open)
            return false;
        if (!host)
            return true;
        const name = nameOf(screen);
        if (name && name === host)
            return true;
        const mon = Hypr.monitorForScreen(screen);
        return !!(mon && String(mon.name) === host);
    }

    function nameOf(screen: var): string {
        if (screen && screen.name)
            return String(screen.name);
        return "";
    }

    function focused(): string {
        const hyprName = Hypr.focusedMonitorName();
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            const s = screens[i];
            if (!s)
                continue;
            if (hyprName && s.name && String(s.name) === hyprName)
                return String(s.name);
            const mon = Hypr.monitorForScreen(s);
            if (hyprName && mon && String(mon.name) === hyprName)
                return String(s.name || mon.name);
        }
        if (hyprName)
            return hyprName;
        if (screens.length > 0 && screens[0] && screens[0].name)
            return String(screens[0].name);
        return "";
    }
}
