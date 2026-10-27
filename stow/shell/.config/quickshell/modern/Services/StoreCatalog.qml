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
    property var apps: ({})
    readonly property int shelfSize: 6
    readonly property int popularSize: 9
    readonly property int searchCap: 30
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
        for (let s = 0; s < stems.length; s++) {
            if (root._themeIcon(stems[s]))
                return stems[s];
        }
        return "";
    }

    function _themeIcon(name: string): bool {
        const p = Quickshell.iconPath(String(name || ""), true);
        return String(p || "").length > 0;
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
        const pop = root._take(root.popular, root.popularSize);
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
            root.apps = data.apps && typeof data.apps === "object" ? data.apps : ({});
        } catch (e) {
            root.popular = [];
            root.categories = root._fallback();
            root.icons = ({});
            root.apps = ({});
        }
    }

    function title(name: string): string {
        const a = root.apps[String(name || "")];
        return a && a.title ? String(a.title) : String(name || "");
    }

    // Curated apps carry a translated one-liner; everything else keeps
    // pacman's English description.
    function desc(name: string, fallback: string): string {
        const n = String(name || "");
        if (!root.apps[n])
            return String(fallback || "");
        return I18n.t("store.apps." + n.replace(/[^a-z0-9]/g, "_"));
    }

    // Every word must hit the name, title, tags (en + de) or the
    // translated description. Title hits rank first.
    function search(query: string) {
        const q = String(query || "").toLowerCase().trim();
        const words = q.replace(/[\s,.;:()\/+-]+/g, " ").split(" ").filter((w) => w.length > 0);
        if (!words.length)
            return [];
        const catOf = {};
        for (const c of root.categories || []) {
            const label = c.id + " " + I18n.t("store.categories." + c.id).toLowerCase();
            for (const p of c.packages || [])
                catOf[p] = (catOf[p] || "") + " " + label;
        }
        const hits = [];
        for (const n in root.apps) {
            const a = root.apps[n] || {};
            const t = String(a.title || n).toLowerCase();
            const tags = (a.tags || []).join(" ").toLowerCase();
            const hay = " " + (n + " " + t + " " + tags + " " + root.desc(n, "").toLowerCase() + (catOf[n] || ""))
                .replace(/[\s,.;:()\/+-]+/g, " ");
            if (!words.every((w) => hay.indexOf(" " + w) !== -1 || hay.indexOf(" " + root._stem(w)) !== -1))
                continue;
            const tagHit = (" " + tags + " ").indexOf(" " + q + " ") !== -1;
            const rank = t.indexOf(q) === 0 ? 0 : (tagHit ? 1 : (t.indexOf(q) !== -1 ? 2 : 3));
            hits.push({ n: n, rank: rank, i: hits.length });
        }
        hits.sort((x, y) => x.rank - y.rank || x.i - y.i);
        return hits.slice(0, root.searchCap).map((h) => h.n);
    }

    // "editing" -> "edit", "bearbeitung" -> "bearbeit": enough for the
    // everyday words people type without a real stemmer.
    function _stem(word: string): string {
        const cut = String(word || "").replace(/(ing|ung|en|er|s)$/, "");
        return cut.length >= 4 ? cut : String(word || "");
    }

    function _fallback() {
        return [
            { id: "discover", icon: "view-grid-symbolic" },
            { id: "installed", icon: "folder-download-symbolic" }
        ];
    }
}
