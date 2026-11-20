// Search hits stay folders-first, then by the score the walk assigned.
import QtQuick
import "../../Commons"
import "../../Services"

QtObject {
    id: root

    function order(list, foldersFirst) {
        const src = list || [];
        const out = [];
        for (let i = 0; i < src.length; i++)
            out.push(src[i]);
        const folders = foldersFirst !== false;
        out.sort((a, b) => {
            const ad = !!(a && a.dir);
            const bd = !!(b && b.dir);
            if (folders && ad !== bd)
                return ad ? -1 : 1;
            const ds = Number((b && b.score) || 0) - Number((a && a.score) || 0);
            if (ds !== 0)
                return ds;
            const an = String((a && a.name) || "").toLowerCase();
            const bn = String((b && b.name) || "").toLowerCase();
            if (an < bn)
                return -1;
            if (an > bn)
                return 1;
            return 0;
        });
        return out;
    }

    function _where(path, here) {
        const parts = String(path || "").split("/").filter(part => part.length > 0);
        if (parts.length <= 1)
            return I18n.t("files.search.folder");
        const parent = parts.slice(0, -1);
        const opened = String(here || "").split("/").filter(part => part.length > 0);
        if (parent.join("/") === opened.join("/"))
            return I18n.t("files.search.folder");
        return parent.slice(-2).join(" / ");
    }

    function collect(query, found, local, here, place, foldersFirst, limit) {
        const needle = String(query || "").toLowerCase();
        if (!needle.length)
            return [];
        const seen = {};
        const rows = [];
        const lists = place === "folder" ? [found, local] : [found];
        for (let n = 0; n < lists.length; n++) {
            const source = lists[n] || [];
            for (let i = 0; i < source.length; i++) {
                const row = source[i];
                const path = row && row.path ? String(row.path) : "";
                if (!path.length || seen[path])
                    continue;
                const name = String(row.name || "").toLowerCase();
                const scored = Number(row.score || 0) > 0;
                const at = name.indexOf(needle);
                if (!scored && at < 0 && path.toLowerCase().indexOf(needle) < 0)
                    continue;
                seen[path] = true;
                rows.push({
                    path: path,
                    name: row.name || path,
                    dir: !!row.dir,
                    where: root._where(path, String(here || "")),
                    score: scored ? Number(row.score) : (at === 0 ? 40 : (at > 0 ? 20 : 10))
                });
            }
        }
        const ranked = root.order(rows, foldersFirst);
        const hit = root._pin(query, here);
        if (!hit)
            return ranked.slice(0, limit);
        const rest = [];
        for (let i = 0; i < ranked.length; i++) {
            if (String(ranked[i].path || "") !== hit.path)
                rest.push(ranked[i]);
        }
        return [hit].concat(rest).slice(0, limit);
    }

    // The typed path is a place, so it stays above name matches.
    function _pin(query, here) {
        if (!FilesLocate.same(query))
            return null;
        const path = String(FilesLocate.path || "");
        return {
            path: path,
            name: String(FilesLocate.name || path),
            dir: !!FilesLocate.dir,
            where: root._where(path, String(here || "")),
            score: 1000
        };
    }
}
