// Bar popup registry. Super+Q dismisses every menu; opening one
// popup claims exclusivity so the others close first.
pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    property int openCount: 0
    property var active: null
    signal closeRequested()
    signal exclusive(var keeper)

    function claim(popup: var) {
        if (!popup || root.active === popup)
            return;
        root.active = popup;
        root.exclusive(popup);
    }

    function opened(popup: var) {
        if (popup)
            root.claim(popup);
        root.openCount += 1;
    }

    function closed(popup: var) {
        if (popup && root.active === popup)
            root.active = null;
        root.openCount = Math.max(0, root.openCount - 1);
    }

    function dismiss(): bool {
        if (root.openCount <= 0)
            return false;
        root.active = null;
        root.closeRequested();
        return true;
    }
}
