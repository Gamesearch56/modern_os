// Minimal markdown → HTML for chat bubbles. Qt MarkdownText collapses
// empty blocks to zero height, so we emit RichText with real margins.
import QtQuick
import "../Commons"

QtObject {
    id: root

    readonly property int blockGap: Math.round(Tokens.spacing.sm)

    function blocks(src: string): var {
        const lines = String(src || "").replace(/\r/g, "").trim().split("\n");
        const gap = root.blockGap;
        const chunks = root._collect(lines);
        const out = [];
        let html = "";
        function flush() {
            if (!html.length)
                return;
            out.push({ kind: "html", html: html });
            html = "";
        }
        for (let i = 0; i < chunks.length; i++) {
            const c = chunks[i];
            const lastChunk = i === chunks.length - 1;
            if (c.type === "table") {
                flush();
                out.push({ kind: "table", rows: c.rows, align: c.align });
                continue;
            }
            if (c.type === "p") {
                const m = lastChunk ? "0" : ("0 0 " + gap + "px 0");
                html += "<p style=\"margin:" + m + "\">" + root._inline(c.text) + "</p>";
                continue;
            }
            const outer = lastChunk ? "0" : ("0 0 " + gap + "px 0");
            html += "<" + c.type + " style=\"margin:" + outer + "\">";
            for (let j = 0; j < c.items.length; j++) {
                const lastLi = lastChunk && j === c.items.length - 1;
                const lm = lastLi ? "0" : ("0 0 " + gap + "px 0");
                html += "<li style=\"margin:" + lm + "\">" + root._inline(c.items[j]) + "</li>";
            }
            html += "</" + c.type + ">";
        }
        flush();
        return out;
    }

    function _collect(lines: var): var {
        const chunks = [];
        let list = null;

        function flushList() {
            if (!list)
                return;
            chunks.push(list);
            list = null;
        }

        for (let i = 0; i < lines.length; i++) {
            const trimmed = String(lines[i] || "").trim();
            if (!trimmed.length)
                continue;
            const table = root._takeTable(lines, i);
            if (table) {
                flushList();
                chunks.push(table.chunk);
                i = table.next - 1;
                continue;
            }
            const ol = trimmed.match(/^(\d+)\.\s+(.*)$/);
            const ul = trimmed.match(/^[-*•]\s+(.*)$/);
            if (ol || ul) {
                const ordered = !!ol;
                const body = ol ? ol[2] : ul[1];
                if (!list || list.ordered !== ordered) {
                    flushList();
                    list = { type: ordered ? "ol" : "ul", ordered: ordered, items: [] };
                }
                list.items.push(body);
                continue;
            }
            flushList();
            chunks.push({ type: "p", text: trimmed });
        }
        flushList();
        return chunks;
    }

    function hasTable(src: string): bool {
        const lines = String(src || "").replace(/\r/g, "").split("\n");
        for (let i = 0; i < lines.length; i++) {
            if (!String(lines[i] || "").trim().length)
                continue;
            const ruleAt = root._nextFilled(lines, i + 1);
            if (ruleAt < lines.length && root._cells(lines[i]).length >= 2 && root._isRule(lines[ruleAt]))
                return true;
        }
        return false;
    }

    function _cells(line: string): var {
        let t = String(line || "").trim();
        if (!t.length || t.indexOf("|") < 0)
            return [];
        if (t.charAt(0) === "|")
            t = t.slice(1);
        if (t.charAt(t.length - 1) === "|")
            t = t.slice(0, -1);
        if (t.indexOf("|") < 0)
            return [];
        const parts = t.split("|");
        const out = [];
        for (let i = 0; i < parts.length; i++)
            out.push(parts[i].trim());
        return out;
    }

    function _isRule(line: string): bool {
        const cells = root._cells(line);
        if (cells.length < 2)
            return false;
        for (let i = 0; i < cells.length; i++) {
            if (!/^:?-{3,}:?$/.test(cells[i]))
                return false;
        }
        return true;
    }

    function _align(cell: string): string {
        const left = cell.charAt(0) === ":";
        const right = cell.charAt(cell.length - 1) === ":";
        if (left && right)
            return "center";
        if (right)
            return "right";
        return "left";
    }

    function _nextFilled(lines: var, at: int): int {
        let k = at;
        while (k < lines.length && !String(lines[k] || "").trim().length)
            k++;
        return k;
    }

    function _fit(cells: var, width: int): var {
        const out = [];
        for (let i = 0; i < width; i++)
            out.push(i < cells.length ? cells[i] : "");
        if (cells.length > width && width > 0) {
            let extra = out[width - 1];
            for (let i = width; i < cells.length; i++)
                extra += " | " + cells[i];
            out[width - 1] = extra;
        }
        return out;
    }

    function _takeTable(lines: var, at: int): var {
        const ruleAt = root._nextFilled(lines, at + 1);
        if (ruleAt >= lines.length)
            return null;
        const head = root._cells(lines[at]);
        if (head.length < 2 || !root._isRule(lines[ruleAt]))
            return null;
        const rule = root._cells(lines[ruleAt]);
        const align = [];
        const width = head.length;
        for (let c = 0; c < width; c++)
            align.push(root._align(rule[c] || ""));
        const rows = [root._fit(head, width)];
        let k = ruleAt + 1;
        while (k < lines.length) {
            if (!String(lines[k] || "").trim().length) {
                const n = root._nextFilled(lines, k);
                if (n >= lines.length)
                    break;
                const peek = root._cells(lines[n]);
                if (peek.length < 2 || root._isRule(lines[n]))
                    break;
                k = n;
                continue;
            }
            const cells = root._cells(lines[k]);
            if (cells.length < 2 || root._isRule(lines[k]))
                break;
            rows.push(root._fit(cells, width));
            k++;
        }
        return { next: k, chunk: { type: "table", rows: rows, align: align } };
    }

    function _tableHtml(table: var, last: bool): string {
        const gap = last ? "0" : (root.blockGap + "px");
        const head = String(Colors.color.surfaceContainer);
        let html = "<table border=\"1\" cellspacing=\"0\" cellpadding=\"4\" width=\"100%\""
            + " style=\"margin:0 0 " + gap + " 0\">";
        const rows = table.rows || [];
        for (let r = 0; r < rows.length; r++) {
            html += "<tr" + (r === 0 ? " bgcolor=\"" + head + "\"" : "") + ">";
            const tag = r === 0 ? "th" : "td";
            for (let c = 0; c < rows[r].length; c++) {
                const align = (table.align && table.align[c]) || "left";
                html += "<" + tag + " align=\"" + align + "\">" + root._inline(rows[r][c]) + "</" + tag + ">";
            }
            html += "</tr>";
        }
        html += "</table>";
        return html;
    }

    function _escape(s: string): string {
        return String(s || "")
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;");
    }

    function _inline(s: string): string {
        let t = root._escape(s);
        t = t.replace(/`([^`]+)`/g, "<code>$1</code>");
        t = t.replace(/\*\*([^*]+)\*\*/g, "<b>$1</b>");
        t = t.replace(/(^|[^*])\*([^*]+)\*(?!\*)/g, "$1<i>$2</i>");
        return t;
    }
}
