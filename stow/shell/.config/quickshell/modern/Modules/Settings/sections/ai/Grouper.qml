import QtQuick

QtObject {
    function build(installed, results, fetched, query, active) {
        const q = String(query || "").trim().toLowerCase();
        const current = String(active || "").replace(/:latest$/, "");
        function inUse(name) {
            return String(name || "").replace(/:latest$/, "") === current && current.length > 0;
        }
        const order = [];
        const by = {};
        function ensure(family, desc, use, also) {
            if (!by[family]) {
                by[family] = {
                    family: family,
                    desc: desc || "",
                    use: use || "chat",
                    also: also || [],
                    tags: []
                };
                order.push(family);
            } else {
                if (desc && !by[family].desc)
                    by[family].desc = desc;
                if (use) {
                    by[family].use = use;
                    by[family].also = also || [];
                }
            }
            return by[family];
        }
        function addFull(full, isInstalled, desc, bytes) {
            const raw = String(full || "");
            if (!raw.length)
                return;
            const cut = raw.indexOf(":");
            const family = cut < 0 ? raw : raw.slice(0, cut);
            const label = cut < 0 ? "" : raw.slice(cut + 1);
            const g = ensure(family, cut < 0 ? desc : "", "", []);
            const size = Number(bytes || 0);
            if (!label.length) {
                if (!isInstalled)
                    return;
                for (let n = 0; n < g.tags.length; n++) {
                    if (g.tags[n].name === family) {
                        if (size > 0)
                            g.tags[n].bytes = size;
                        return;
                    }
                }
                g.tags.push({ name: family, label: family, installed: true, inUse: inUse(family), bytes: size });
                return;
            }
            const name = family + ":" + label;
            for (let i = 0; i < g.tags.length; i++) {
                if (g.tags[i].name === name) {
                    if (isInstalled)
                        g.tags[i].installed = true;
                    g.tags[i].inUse = inUse(name);
                    if (size > 0)
                        g.tags[i].bytes = size;
                    return;
                }
            }
            g.tags.push({ name: name, label: label, installed: isInstalled, inUse: inUse(name), bytes: size });
        }
        const have = {};
        const local = installed || [];
        for (let i = 0; i < local.length; i++) {
            const shown = String(local[i] || "");
            const stem = shown.replace(/:latest$/, "");
            if (!stem.length || have[stem])
                continue;
            have[stem] = true;
            addFull(shown.indexOf(":") < 0 ? stem + ":latest" : shown, true, "");
        }
        const lib = results || [];
        for (let j = 0; j < lib.length; j++) {
            const name = String(lib[j] && lib[j].name || "");
            const desc = String(lib[j] && lib[j].desc || "");
            if (!name.length)
                continue;
            if (name.indexOf(":") < 0) {
                ensure(name, desc, String(lib[j].use || ""), lib[j].also || []);
                const sizes = lib[j].sizes || [];
                for (let s = 0; s < sizes.length; s++) {
                    const tag = String(sizes[s] || "");
                    if (!tag.length)
                        continue;
                    const full = name + ":" + tag;
                    addFull(full, !!have[full.replace(/:latest$/, "")], "");
                }
            } else {
                addFull(name, !!have[name.replace(/:latest$/, "")], desc);
            }
        }
        const extra = fetched || {};
        for (const family in extra) {
            const list = extra[family] || [];
            for (let t = 0; t < list.length; t++) {
                const tagName = String(list[t] && list[t].name || "");
                addFull(tagName, !!have[tagName.replace(/:latest$/, "")], "", Number(list[t] && list[t].bytes || 0));
            }
        }
        const out = [];
        for (let g = 0; g < order.length; g++) {
            const group = by[order[g]];
            function rank(label) {
                const match = String(label || "").toLowerCase().match(/^(?:e)?([0-9]+(?:\.[0-9]+)?)([mb])/);
                if (!match)
                    return 1e9;
                let n = parseFloat(match[1]);
                if (match[2] === "m")
                    n /= 1000;
                return n;
            }
            group.tags.sort((a, b) => {
                const na = rank(a.label);
                const nb = rank(b.label);
                if (na !== nb)
                    return na - nb;
                return a.label < b.label ? -1 : (a.label > b.label ? 1 : 0);
            });
            if (group.tags.length === 0)
                continue;
            if (q.length) {
                const hay = (group.family + " " + group.desc).toLowerCase();
                let tagHit = false;
                for (let t = 0; t < group.tags.length; t++) {
                    if (group.tags[t].name.toLowerCase().indexOf(q) !== -1)
                        tagHit = true;
                }
                if (hay.indexOf(q) === -1 && !tagHit)
                    continue;
            }
            out.push(group);
        }
        return out;
    }
}
