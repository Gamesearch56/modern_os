// Bar task-manager popup open state. Notifications toggles this without
// importing Bar internals. `hostScreenName` keeps the popup on the bar
// that opened it (or the focused monitor from the control panel).
pragma Singleton

import Quickshell
import QtQuick
import "../Commons"

Singleton {
    id: root

    property bool open: false
    property string hostScreenName: ""

    function toggle(screen: var) {
        const name = root._nameOf(screen) || root._focusedName();
        if (root.open && root.hostScreenName === name) {
            root.hide();
            return;
        }
        root.hostScreenName = name;
        root.open = true;
    }

    function show(screen: var) {
        root.hostScreenName = root._nameOf(screen) || root._focusedName();
        root.open = true;
    }

    function hide() {
        root.open = false;
        root.hostScreenName = "";
    }

    function openOn(screen: var): bool {
        if (!root.open)
            return false;
        if (!root.hostScreenName)
            return true;
        const name = root._nameOf(screen);
        if (name && name === root.hostScreenName)
            return true;
        const mon = Hypr.monitorForScreen(screen);
        if (mon && String(mon.name) === root.hostScreenName)
            return true;
        return false;
    }

    function _nameOf(screen: var): string {
        if (screen && screen.name)
            return String(screen.name);
        return "";
    }

    function _focusedName(): string {
        const n = Hypr.focusedMonitorName();
        if (n && n.length)
            return n;
        const list = Quickshell.screens;
        if (list && list.length > 0 && list[0].name)
            return String(list[0].name);
        return "";
    }
}
