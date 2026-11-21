import Quickshell
import QtQuick
import "../../Commons"
import "../../Services"
import "links.js" as Links

// ModernOS Manual: one window per process (scripts/modern-manual). It
// opens on the first manual chapter, or on MODERN_MANUAL_DOC when the
// launcher names a document. Links between documents stay in the
// window and can be retraced with Back and Forward.
Scope {
    id: root

    property string current: ""
    property var history: []
    property var future: []
    readonly property var doc: ManualDocs.byPath(root.current)
    readonly property bool canGoBack: root.history.length > 0
    readonly property bool canGoForward: root.future.length > 0

    function open(path: string) {
        if (!path.length || path === root.current || !ManualDocs.byPath(path))
            return false;
        if (root.current.length)
            root.history = root.history.concat([root.current]);
        root.future = [];
        root.current = path;
        return true;
    }

    function back() {
        if (!root.canGoBack)
            return;
        const h = root.history.slice();
        root.future = root.future.concat([root.current]);
        root.current = h.pop();
        root.history = h;
    }

    function forward() {
        if (!root.canGoForward)
            return;
        const f = root.future.slice();
        root.history = root.history.concat([root.current]);
        root.current = f.pop();
        root.future = f;
    }

    function follow(link: string) {
        if (Links.isExternal(link)) {
            ManualDocs.openExternal(link);
            return;
        }
        const target = Links.resolve(root.current, link);
        if (target.length && !root.open(target))
            Logger.info("Manual", "no document at " + target);
    }

    function _start() {
        const wanted = Quickshell.env("MODERN_MANUAL_DOC") || "";
        if (wanted.length && ManualDocs.byPath(wanted)) {
            root.current = wanted;
            return;
        }
        if (!ManualDocs.byPath(root.current) && ManualDocs.docs.length)
            root.current = ManualDocs.docs[0].path;
    }

    Connections {
        target: ManualDocs
        function onLoaded() { root._start(); }
    }

    LazyLoader {
        active: true
        ManualWindow {
            module: root
        }
    }
}
