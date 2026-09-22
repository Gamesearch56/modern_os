// Minimal markdown → HTML for chat bubbles. Qt MarkdownText collapses
// empty blocks to zero height, so we emit RichText with real margins.
import QtQuick
import "../Commons"

QtObject {
    id: root

    readonly property int blockGap: Math.round(Tokens.spacing.sm)

    function toHtml(src: string): string {
        const lines = String(src || "").replace(/\r/g, "").trim().split("\n");
        const gap = root.blockGap;
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

        let html = "";
        for (let i = 0; i < chunks.length; i++) {
            const c = chunks[i];
            const lastChunk = i === chunks.length - 1;
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
