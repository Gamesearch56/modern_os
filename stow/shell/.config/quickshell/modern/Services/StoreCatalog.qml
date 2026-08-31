// Curated popular + category allowlists from store/catalog.json.
import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Item {
    id: root
    visible: false
    width: 0
    height: 0

    property var popular: []
    property var categories: []
    property var icons: ({})
    readonly property int shelfSize: 6
    signal loaded()

    FileView {
        path: Paths.configHome + "/modern/store/catalog.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            root._parse(text());
            root.loaded();
        }
        onLoadFailed: {
            root._parse("");
            root.loaded();
        }
    }

    function iconFor(id: string): string {
        const cats = root.categories;
        for (let i = 0; i < cats.length; i++) {
            if (cats[i].id === id)
                return cats[i].icon || "package-x-generic-symbolic";
        }
        return "package-x-generic-symbolic";
    }

    function iconForPkg(name: string): string {
        const n = String(name || "").toLowerCase();
        if (!n.length)
            return "package-x-generic";
        const mapped = root.icons && root.icons[n] ? String(root.icons[n]) : "";
        if (mapped.length)
            return mapped;
        const stems = root._stems(n);
        try {
            const entries = DesktopEntries.applications.values;
            for (let i = 0; i < entries.length; i++) {
                const e = entries[i];
                const id = String(e.id || "").replace(/\.desktop$/i, "").toLowerCase();
                const last = id.indexOf(".") >= 0 ? id.substring(id.lastIndexOf(".") + 1) : id;
                const icon = String(e.icon || "");
                for (let s = 0; s < stems.length; s++) {
                    const stem = stems[s];
                    if (id === stem || last === stem || icon.toLowerCase() === stem)
                        return icon.length ? icon : stem;
                }
            }
        } catch (err) {
        }
        return n;
    }

    function packages(id: string) {
        const cats = root.categories;
        for (let i = 0; i < cats.length; i++) {
            if (cats[i].id === id)
                return cats[i].packages || [];
        }
        return [];
    }

    function discoverLayout() {
        const out = [];
        const pop = root._take(root.popular, root.shelfSize);
        if (pop.length)
            out.push({ id: "popular", names: pop });
        const cats = root.categories || [];
        for (let i = 0; i < cats.length; i++) {
            const c = cats[i];
            if (!c || c.id === "discover" || c.id === "installed")
                continue;
            const names = root._take(c.packages, root.shelfSize);
            if (names.length)
                out.push({ id: c.id, names: names });
        }
        return out;
    }

    function discoverNames() {
        const seen = {};
        const out = [];
        const layout = root.discoverLayout();
        for (let i = 0; i < layout.length; i++) {
            const names = layout[i].names || [];
            for (let j = 0; j < names.length; j++) {
                const n = String(names[j] || "");
                if (!n.length || seen[n])
                    continue;
                seen[n] = true;
                out.push(n);
            }
        }
        return out;
    }

    function groupRows(rows) {
        try {
            return root._groupRows(rows);
        } catch (e) {
            return [];
        }
    }

    function _groupRows(rows) {
        const byName = {};
        const list = rows || [];
        for (let i = 0; i < list.length; i++) {
            const n = String(list[i] && list[i].name || "");
            if (n.length)
                byName[n] = list[i];
        }
        const layout = root.discoverLayout();
        const out = [];
        for (let i = 0; i < layout.length; i++) {
            const s = layout[i];
            const pkgs = [];
            const names = s.names || [];
            for (let j = 0; j < names.length; j++) {
                const pkg = byName[names[j]];
                if (pkg)
                    pkgs.push(pkg);
            }
            if (pkgs.length)
                out.push({ id: s.id, packages: pkgs });
        }
        return out;
    }

    function _take(list, n: int) {
        const src = list || [];
        const out = [];
        for (let i = 0; i < src.length && out.length < n; i++) {
            const name = String(src[i] || "");
            if (name.length)
                out.push(name);
        }
        return out;
    }

    function _stems(name: string) {
        const n = String(name || "");
        const out = [n];
        const cut = n.replace(/-git$/, "").replace(/-bin$/, "").replace(/-desktop$/, "")
            .replace(/-gtk$/, "").replace(/-qt$/, "").replace(/-fresh$/, "");
        if (cut !== n && cut.length)
            out.push(cut);
        return out;
    }

    function _parse(text: string) {
        try {
            const data = JSON.parse(String(text || "").trim() || "{}");
            root.popular = Array.isArray(data.popular) ? data.popular : [];
            root.categories = Array.isArray(data.categories) && data.categories.length
                ? data.categories
                : root._fallback();
            root.icons = data.icons && typeof data.icons === "object" ? data.icons : ({});
        } catch (e) {
            root.popular = [];
            root.categories = root._fallback();
            root.icons = ({});
        }
    }

    function _fallback() {
        return [
            { id: "discover", icon: "view-grid-symbolic" },
            { id: "installed", icon: "folder-download-symbolic" }
        ];
    }
}
