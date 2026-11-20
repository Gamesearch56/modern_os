pragma Singleton
// Ctrl adds or removes one item. Shift selects the rows between the last
// plain click and this one. A right-click keeps a selection it lands on.
import Quickshell
import QtQuick

Singleton {
    id: root

    property string anchor: ""

    function pick(file: string, extra: bool, range: bool, rows: var) {
        const id = String(file || "");
        if (!id)
            return;
        if (range) {
            root._span(id, rows || []);
            return;
        }
        root.anchor = id;
        if (!extra) {
            Files.selected = [id];
            return;
        }
        const cur = (Files.selected || []).slice();
        const at = cur.indexOf(id);
        if (at >= 0)
            cur.splice(at, 1);
        else
            cur.push(id);
        Files.selected = cur;
    }

    function retain(file: string): bool {
        const id = String(file || "");
        const cur = Files.selected || [];
        if (cur.indexOf(id) >= 0)
            return cur.length > 1;
        Files.click(id, false);
        root.anchor = id;
        return false;
    }

    function _span(file: string, rows: var) {
        const order = [];
        for (let i = 0; i < rows.length; i++) {
            const row = rows[i];
            if (!row || row.readable === false || row.canRead === false)
                continue;
            const path = String(row.path || row.uri || "");
            if (path)
                order.push(path);
        }
        let from = order.indexOf(root.anchor);
        let to = order.indexOf(file);
        if (from < 0)
            from = to;
        if (to < 0)
            return;
        if (from > to) {
            const swap = from;
            from = to;
            to = swap;
        }
        const next = [];
        for (let i = from; i <= to; i++)
            next.push(order[i]);
        Files.selected = next;
    }
}
