// Visual-order arrow focus. Settings and overlays walk tabbable
// descendants with Up/Down/Left/Right instead of Tab.
import QtQuick
import QtQuick.Window
import "../Commons"

QtObject {
    id: root

    property Item scope: null
    property Flickable flick: null

    function move(dx: int, dy: int): bool {
        const list = root._items();
        if (list.length === 0)
            return false;
        const idx = root._indexOf(list, root._focused());
        if (idx < 0) {
            if (dx < 0 || dy < 0)
                return false;
            root._focus(list[0], true);
            return true;
        }
        const next = root._pick(list, idx, dx, dy);
        if (!next)
            return false;
        root._focus(next, true);
        return true;
    }

    function focusFirst(reveal: bool): bool {
        const list = root._items();
        if (list.length === 0)
            return false;
        root._focus(list[0], !!reveal);
        return true;
    }

    function focusLast(reveal: bool): bool {
        const list = root._items();
        if (list.length === 0)
            return false;
        root._focus(list[list.length - 1], !!reveal);
        return true;
    }

    function ownsFocus(): bool {
        return root._indexOf(root._items(), root._focused()) >= 0;
    }

    function _focused(): var {
        const s = root.scope;
        if (!s)
            return null;
        const win = s.Window.window;
        return win ? win.activeFocusItem : null;
    }

    function _indexOf(list: var, item: var): int {
        if (!item)
            return -1;
        for (let i = 0; i < list.length; i++) {
            if (list[i] === item || root._contains(list[i], item))
                return i;
        }
        return -1;
    }

    function _contains(outer: var, inner: var): bool {
        let p = inner;
        while (p) {
            if (p === outer)
                return true;
            p = p.parent;
        }
        return false;
    }

    function _ringOf(item: var): var {
        const kids = item ? item.children : null;
        if (!kids)
            return null;
        for (let i = 0; i < kids.length; i++) {
            if (kids[i] && typeof kids[i].markKeyboard === "function")
                return kids[i];
        }
        return null;
    }

    function _focus(item: var, reveal: bool) {
        if (!item || typeof item.forceActiveFocus !== "function")
            return;
        item.forceActiveFocus();
        const ring = root._ringOf(item);
        if (ring) {
            if (reveal)
                ring.markKeyboard();
            else
                ring.markPointer();
        }
        root._reveal(item);
    }

    function _reveal(item: var) {
        const flick = root.flick;
        if (!flick || !item || !flick.contentItem)
            return;
        try {
            const p = item.mapToItem(flick.contentItem, 0, 0);
            const pad = Tokens.spacing.md;
            const top = p.y;
            const bottom = top + Math.max(item.height, 1);
            const viewTop = flick.contentY;
            const viewBottom = viewTop + flick.height;
            const maxY = Math.max(0, flick.contentHeight - flick.height);
            let y = flick.contentY;
            if (top < viewTop + pad)
                y = top - pad;
            else if (bottom > viewBottom - pad)
                y = bottom - flick.height + pad;
            flick.contentY = Math.max(0, Math.min(maxY, y));
        } catch (e) {
        }
    }

    function _ok(item: var): bool {
        if (!item || item.visible === false || item.enabled === false)
            return false;
        if (item.opacity !== undefined && item.opacity < 0.01)
            return false;
        if (item.width <= 0 || item.height <= 0)
            return false;
        return !!item.activeFocusOnTab;
    }

    function _walk(item: var, out: var, seen: var, skip: bool) {
        if (!item || seen.indexOf(item) >= 0 || item.visible === false)
            return;
        seen.push(item);
        if (!skip && root._ok(item))
            out.push(item);
        const kids = item.children;
        if (kids) {
            for (let i = 0; i < kids.length; i++)
                root._walk(kids[i], out, seen, false);
        }
        if (item.item && typeof item.item.forceActiveFocus === "function")
            root._walk(item.item, out, seen, false);
    }

    function _center(item: var): var {
        return item.mapToItem(root.scope, item.width / 2, item.height / 2);
    }

    function _pick(list: var, idx: int, dx: int, dy: int): var {
        const c = root._center(list[idx]);
        const slop = Tokens.spacing.lg;
        const min = Tokens.spacing.xs;
        let best = null;
        let bestScore = Infinity;
        for (let i = 0; i < list.length; i++) {
            if (i === idx)
                continue;
            const p = root._center(list[i]);
            const vx = p.x - c.x;
            const vy = p.y - c.y;
            let score = Infinity;
            if (dx !== 0) {
                if (Math.abs(vy) > slop)
                    continue;
                if ((dx > 0 && vx <= min) || (dx < 0 && vx >= -min))
                    continue;
                score = Math.abs(vx) + Math.abs(vy) * 2;
            } else {
                if ((dy > 0 && vy <= min) || (dy < 0 && vy >= -min))
                    continue;
                score = Math.abs(vy) + Math.abs(vx) * 0.35;
            }
            if (score < bestScore) {
                bestScore = score;
                best = list[i];
            }
        }
        return best;
    }

    function _items(): var {
        const out = [];
        if (!root.scope)
            return out;
        root._walk(root.scope, out, [], true);
        out.sort((a, b) => {
            const pa = a.mapToItem(root.scope, 0, 0);
            const pb = b.mapToItem(root.scope, 0, 0);
            if (Math.abs(pa.y - pb.y) > Tokens.spacing.sm)
                return pa.y - pb.y;
            return pa.x - pb.x;
        });
        return out;
    }
}
