// Tabs for the file window. Navigation stays with the caller so this
// service does not depend on Files.
pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    property var paths: []
    property int index: 0

    function follow(path: string) {
        const next = String(path || "");
        if (!next.length)
            return;
        if (!root.paths.length) {
            root.paths = [next];
            root.index = 0;
            return;
        }
        if (root.paths[root.index] === next)
            return;
        const copy = root.paths.slice();
        copy[root.index] = next;
        root.paths = copy;
    }

    function add(folder: string) {
        const next = String(folder || "");
        if (next.charAt(0) !== "/")
            return;
        const copy = root.paths.slice();
        copy.push(next);
        root.paths = copy;
    }

    function pick(at: int) {
        if (at < 0 || at >= root.paths.length)
            return;
        root.index = at;
    }

    // Other tabs are only extra folders. This one stays, and the caller
    // opens it when it was not already the folder on screen.
    function keep(path: string) {
        const next = String(path || "");
        if (root.paths.length < 2 || root.paths.indexOf(next) < 0)
            return;
        root.paths = [next];
        root.index = 0;
    }

    function closeAt(at: int) {
        if (root.paths.length < 2 || at < 0 || at >= root.paths.length)
            return;
        const copy = root.paths.slice();
        copy.splice(at, 1);
        let current = root.index;
        if (at < current)
            current -= 1;
        else if (at === current)
            current = Math.min(current, copy.length - 1);
        root.paths = copy;
        root.index = current;
    }
}
