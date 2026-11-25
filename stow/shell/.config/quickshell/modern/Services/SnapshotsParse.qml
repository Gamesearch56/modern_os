// Snapper list JSON / table rows. Host is the Snapshots singleton.
import QtQuick
import "../Commons"

QtObject {
    id: root

    function parseList(text: string): var {
        const t = String(text || "").trim();
        if (t.charAt(0) === "[" || t.charAt(0) === "{") {
            try {
                return root._fromJson(JSON.parse(t));
            } catch (e) {
                Logger.warn("Snapshots", String(e));
            }
        }
        return root._fromTable(t);
    }

    function _fromJson(j: var): var {
        let arr = [];
        if (Array.isArray(j))
            arr = j;
        else if (j && Array.isArray(j.root))
            arr = j.root;
        const out = [];
        for (let i = 0; i < arr.length; i++) {
            const it = root._norm(arr[i]);
            if (it)
                out.push(it);
        }
        return out;
    }

    function _fromTable(text: string): var {
        const out = [];
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            if (!line || line.indexOf("---") !== -1 || line.indexOf("Type") !== -1)
                continue;
            const p = line.split("|");
            if (p.length < 7)
                continue;
            const it = root._norm({
                number: p[0],
                type: p[1],
                date: p[3],
                user: p[4],
                cleanup: p[5],
                description: p[6]
            });
            if (it)
                out.push(it);
        }
        return out;
    }

    function _norm(row: var): var {
        const n = String(row.number ?? row["#"] ?? "").trim();
        if (!n || n === "0")
            return null;
        return {
            number: n,
            date: String(row.date || "").trim(),
            description: String(row.description || "").trim(),
            type: String(row.type || "").trim(),
            cleanup: String(row.cleanup || "").trim(),
            user: String(row.user || "").trim()
        };
    }

    function formatWhen(raw: string): string {
        const s = String(raw || "").trim();
        if (!s.length)
            return "";
        const iso = s.indexOf("T") !== -1 ? s : s.replace(" ", "T");
        const d = new Date(iso);
        if (isNaN(d.getTime()))
            return s;
        return DateTime.clockLabel(
            d,
            Config.language.dateFormat || "DD.MM.YYYY",
            Config.language.timeFormat || "HH:mm",
            false,
            false);
    }
}
