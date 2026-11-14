// Port / address / comment checks plus `ufw status numbered` row parse.
import QtQuick

QtObject {
    id: root

    function portOk(s): bool {
        const m = String(s || "").trim().match(/^(\d{1,5})(?::(\d{1,5}))?$/);
        if (!m)
            return false;
        const a = Number(m[1]);
        const b = m[2] !== undefined ? Number(m[2]) : a;
        if (a < 1 || b < 1 || a > 65535 || b > 65535 || a > b)
            return false;
        if (a === 1 && b === 65535)
            return false;
        return (b - a + 1) <= 512;
    }

    function commentOk(s): bool {
        const t = String(s || "").trim();
        if (t.length === 0)
            return true;
        return t.length <= 40 && t.charAt(0) !== "-" && /^[A-Za-z0-9._: -]+$/.test(t);
    }

    function fromOk(s): bool {
        const t = String(s || "").trim();
        if (t.length === 0)
            return true;
        const low = t.toLowerCase();
        if (low === "any" || low === "anywhere")
            return false;
        if (t.indexOf(":") !== -1)
            return root._v6(t);
        return root._v4(t);
    }

    function parseStatus(text: string): var {
        const t = String(text || "");
        const low = t.toLowerCase();
        let status = "";
        if (low.indexOf("status: missing") !== -1)
            status = "missing";
        else if (low.indexOf("status: active") !== -1)
            status = "active";
        else if (low.indexOf("status: inactive") !== -1)
            status = "inactive";
        const allow = [];
        const deny = [];
        const lines = t.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const row = root.parseRow(lines[i]);
            if (!row)
                continue;
            if (row.action === "ALLOW")
                allow.push(row);
            else
                deny.push(row);
        }
        return { status: status, allow: allow, deny: deny };
    }

    function parseRow(line: string): var {
        const m = String(line || "").match(/^\[\s*(\d+)\]\s+(.+?)\s+(ALLOW|DENY|REJECT)\s+(IN|OUT)\s+(\S.*)$/);
        if (!m)
            return null;
        let from = String(m[5]).trim();
        let comment = "";
        const hash = from.indexOf(" # ");
        if (hash !== -1) {
            comment = from.slice(hash + 3).trim();
            from = from.slice(0, hash).trim();
        }
        let to = String(m[2]).trim();
        const v6 = /\(v6\)\s*$/.test(to) || /\(v6\)\s*$/.test(from);
        to = to.replace(/\s*\(v6\)\s*$/, "");
        from = from.replace(/\s*\(v6\)\s*$/, "");
        let proto = "";
        const pm = to.match(/\/(tcp|udp)$/i);
        if (pm)
            proto = pm[1].toLowerCase();
        const port = to.replace(/\/(tcp|udp)$/i, "").trim();
        return {
            number: m[1],
            to: to,
            port: port,
            proto: proto,
            direction: String(m[4]).toLowerCase(),
            from: from,
            comment: comment,
            action: m[3],
            v6: v6
        };
    }

    function _v4(s): bool {
        const m = String(s).match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})(?:\/(\d{1,2}))?$/);
        if (!m)
            return false;
        for (let i = 1; i <= 4; i++) {
            const n = Number(m[i]);
            if (n > 255 || (m[i].length > 1 && m[i].charAt(0) === "0"))
                return false;
        }
        return m[5] === undefined || Number(m[5]) <= 32;
    }

    function _v6(s): bool {
        const m = String(s).match(/^([0-9a-fA-F:]+)(?:\/(\d{1,3}))?$/);
        if (!m || String(m[1]).indexOf(":::") !== -1)
            return false;
        if (m[2] !== undefined && Number(m[2]) > 128)
            return false;
        const sides = String(m[1]).split("::");
        if (sides.length > 2)
            return false;
        let n = 0;
        for (let i = 0; i < sides.length; i++) {
            if (sides[i].length === 0)
                continue;
            const g = sides[i].split(":");
            for (let j = 0; j < g.length; j++) {
                if (!/^[0-9a-fA-F]{1,4}$/.test(g[j]))
                    return false;
                n++;
            }
        }
        return sides.length === 1 ? n === 8 : n < 8;
    }
}
