// One open MSelect / MMultiSelect at a time. Widgets stay stateless
// besides calling claim/release; the previous menu closes itself.
pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    property var current: null

    function claim(item: var) {
        if (root.current && root.current !== item && root.current.closeMenu)
            root.current.closeMenu();
        root.current = item;
    }

    function release(item: var) {
        if (root.current === item)
            root.current = null;
    }
}
