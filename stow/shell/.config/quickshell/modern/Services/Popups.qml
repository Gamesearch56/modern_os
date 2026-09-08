// Bar popup registry. Super+Q dismisses every menu; opening one
// popup claims exclusivity so the others close first.
pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    property int openCount: 0
    property var active: null
    property var barHosts: []
    signal closeRequested()
    signal exclusive(var keeper)

    function registerBar(win: var) {
        if (!win)
            return;
        const next = root.barHosts.slice();
        if (next.indexOf(win) !== -1)
            return;
        next.push(win);
        root.barHosts = next;
    }

    function unregisterBar(win: var) {
        root.barHosts = root.barHosts.filter(w => w !== win);
    }

    function barForScreen(screen: var): var {
        void root.barHosts;
        const hosts = root.barHosts;
        const name = screen ? String(screen.name || "") : "";
        for (let i = 0; i < hosts.length; i++) {
            const w = hosts[i];
            if (!w)
                continue;
            if (screen && w.screen === screen)
                return w;
            if (name.length > 0 && w.screen && String(w.screen.name) === name)
                return w;
        }
        return null;
    }

    // Seat grab otherwise owns the pointer; the bar is a second surface
    // so widget buttons keep hover/cursor while a menu is open.
    function grabWindows(popup: var, screen: var): var {
        void root.barHosts;
        const bar = root.barForScreen(screen);
        if (popup && bar && bar !== popup)
            return [popup, bar];
        if (popup)
            return [popup];
        return [];
    }

    function claim(popup: var) {
        if (!popup || root.active === popup)
            return;
        root.active = popup;
        root.exclusive(popup);
    }

    function opened(popup: var) {
        // Hover-only popups (volume slider) must not claim exclusivity —
        // that makes the bar layer-shell focusable and steals the
        // Hyprland client under the pointer.
        if (popup && !popup.hoverBridge)
            root.claim(popup);
        root.openCount += 1;
    }

    function closed(popup: var) {
        if (popup && root.active === popup)
            root.active = null;
        root.openCount = Math.max(0, root.openCount - 1);
    }

    function dismiss(): bool {
        if (!root.active)
            return false;
        root.active = null;
        root.closeRequested();
        return true;
    }
}
