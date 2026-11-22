// Back/forward stack for Store mouse buttons and the chrome back control.
import QtQuick

QtObject {
    id: root

    property var host: null
    property var past: []
    property var future: []
    property bool lock: false

    function snap() {
        const h = root.host;
        return {
            categoryId: h.categoryId,
            query: h.query,
            detailName: h.detailName
        };
    }

    function same(a: var, b: var): bool {
        return a && b && a.categoryId === b.categoryId
            && a.query === b.query && a.detailName === b.detailName;
    }

    function push() {
        if (root.lock || !root.host)
            return;
        const s = root.snap();
        const last = root.past.length ? root.past[root.past.length - 1] : null;
        if (last && root.same(last, s))
            return;
        root.past = root.past.concat([s]);
        root.future = [];
    }

    function back(): bool {
        if (!root.host || root.past.length === 0)
            return false;
        const cur = root.snap();
        const prev = root.past[root.past.length - 1];
        root.past = root.past.slice(0, -1);
        root.future = root.future.concat([cur]);
        root.host.applyNav(prev);
        return true;
    }

    function forward(): bool {
        if (!root.host || root.future.length === 0)
            return false;
        const cur = root.snap();
        const next = root.future[root.future.length - 1];
        root.future = root.future.slice(0, -1);
        root.past = root.past.concat([cur]);
        root.host.applyNav(next);
        return true;
    }
}
