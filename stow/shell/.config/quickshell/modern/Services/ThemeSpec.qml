// Profile slug / equality helpers for Theme.qml (line-cap split).
import QtQuick

QtObject {
    id: root

    function plain(s: string): string {
        return String(s || "").replace(/\u001b\[[0-9;]*m/g, "").trim();
    }

    function norm(p: var): var {
        return {
            variant: String(p.variant || "tonal-spot"),
            mode: String(p.mode || "dark"),
            contrast: String(p.contrast || "standard"),
            sourceMode: String(p.sourceMode || "wallpaper"),
            fixedSeed: p.fixedSeed ?? null
        };
    }

    function slugFor(spec: var): string {
        const s = root.norm(spec);
        let slug = s.variant + "-" + s.mode;
        if (s.contrast !== "standard")
            slug += "-" + s.contrast;
        if (s.sourceMode !== "wallpaper")
            slug += "-fixed";
        return slug.replace(/[^a-z0-9-]+/g, "-");
    }

    function same(a: var, b: var): bool {
        const x = root.norm(a);
        const y = root.norm(b);
        return x.variant === y.variant && x.mode === y.mode && x.contrast === y.contrast
            && x.sourceMode === y.sourceMode && String(x.fixedSeed) === String(y.fixedSeed);
    }

    function findSlug(profiles: var, spec: var): string {
        const list = profiles || [];
        for (let i = 0; i < list.length; i++) {
            if (root.same(list[i], spec))
                return String(list[i].slug || "");
        }
        return "";
    }
}
