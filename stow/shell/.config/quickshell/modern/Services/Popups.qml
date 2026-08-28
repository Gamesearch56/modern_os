// Bar MPopup registry so Super+Q can dismiss menus before killactive.
pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    property int openCount: 0
    signal closeRequested()

    function opened() {
        root.openCount += 1;
    }

    function closed() {
        root.openCount = Math.max(0, root.openCount - 1);
    }

    function dismiss(): bool {
        if (root.openCount <= 0)
            return false;
        root.closeRequested();
        return true;
    }
}
