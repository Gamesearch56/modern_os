// Map a desktop Icon= / window class to a theme name Qt can actually
// paint. Toolbox hashes, *-launcher pixmaps, and mixed-case WM_CLASS
// values often miss Papirus even when the real logo is in the theme.
import Quickshell
import QtQuick

QtObject {
    id: root

    readonly property var _uuid: /-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

    function _push(out: var, seen: var, raw: string) {
        const s = String(raw || "").trim();
        if (!s.length || seen[s])
            return;
        seen[s] = true;
        out.push(s);
        const low = s.toLowerCase();
        if (low !== s && !seen[low]) {
            seen[low] = true;
            out.push(low);
        }
        const stripped = low.replace(root._uuid, "");
        if (stripped !== low)
            root._push(out, seen, stripped);
        if (low.endsWith("-launcher") && low.length > 10)
            root._push(out, seen, low.slice(0, -9));
        if (low.indexOf("jetbrains-") === 0 && low.length > 11)
            root._push(out, seen, low.slice(10));
    }

    function _score(name: string): int {
        const s = String(name || "").toLowerCase();
        if (/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/.test(s))
            return 0;
        if (s.endsWith("-launcher"))
            return 1;
        let n = 4;
        if (s.indexOf(".") !== -1)
            n -= 1;
        if (s.indexOf("jetbrains-") === 0)
            n -= 1;
        return n;
    }

    function _norm(s: string): string {
        return String(s || "").replace(/\.desktop$/i, "").toLowerCase()
            .replace(/[-_]?url[-_]?handler$/i, "").replace(/[\s._-]+/g, "");
    }

    // Vivaldi --app= class is the site, not StartupWMClass. Keep this in
    // step with HyprAutostart so the task list and the launcher share an icon.
    function _urlTokens(needle: string, fieldn: string): bool {
        if (!needle.length || !fieldn.length)
            return false;
        if (needle.indexOf("protonmail") !== -1
                && (fieldn.indexOf("mailproton") !== -1 || fieldn.indexOf("mailprotonme") !== -1))
            return true;
        if (needle.indexOf("protoncalendar") !== -1
                && (fieldn.indexOf("calendarproton") !== -1 || fieldn.indexOf("calendarprotonme") !== -1))
            return true;
        if (needle.indexOf("whatsapp") !== -1
                && (fieldn.indexOf("whatsapp") !== -1 || fieldn.indexOf("webwhatsapp") !== -1))
            return true;
        return false;
    }

    function _scoreField(raw: string, desktopId: string): int {
        const needle = root._norm(desktopId);
        const fieldn = root._norm(raw);
        if (!needle.length || !fieldn.length)
            return 0;
        if (root._urlTokens(needle, fieldn))
            return 1000 + needle.length;
        if (fieldn === needle)
            return 500 + needle.length;
        if (needle.length >= 5 && fieldn.indexOf(needle) !== -1)
            return needle.length;
        return 0;
    }

    function _bestDesktop(hint: string): var {
        const entries = DesktopEntries.applications.values;
        let best = null;
        let bestScore = 0;
        for (let i = 0; i < entries.length; i++) {
            const e = entries[i];
            if (!e || e.noDisplay)
                continue;
            const needles = [e.id, e.startupClass, e.icon];
            let score = 0;
            for (let n = 0; n < needles.length; n++) {
                const sc = root._scoreField(hint, String(needles[n] || ""));
                if (sc > score)
                    score = sc;
            }
            if (score > bestScore) {
                best = e;
                bestScore = score;
            }
        }
        return best;
    }

    function _fromDesktop(hint: string): var {
        const h = String(hint || "").trim();
        if (!h.length)
            return null;
        const byId = DesktopEntries.byId(h) || DesktopEntries.byId(h.replace(/\.desktop$/i, ""));
        if (byId)
            return byId;
        const needle = h.replace(/\.desktop$/i, "").toLowerCase();
        const entries = DesktopEntries.applications.values;
        for (let i = 0; i < entries.length; i++) {
            const e = entries[i];
            const wm = String(e.startupClass || "").toLowerCase();
            const id = String(e.id || "").replace(/\.desktop$/i, "").toLowerCase();
            const ic = String(e.icon || "").toLowerCase();
            if (wm === needle || id === needle || ic === needle)
                return e;
        }
        // Heuristic lookup stops at the browser for a vivaldi-web.* class.
        const specific = root._bestDesktop(h);
        if (specific)
            return specific;
        return DesktopEntries.heuristicLookup(h);
    }

    function nameForHint(hint: string): string {
        const e = root._fromDesktop(hint);
        if (e && e.name)
            return String(e.name);
        return String(hint || "").trim();
    }

    function resolve(hint: string): string {
        const raw = String(hint || "").trim();
        if (!raw.length)
            return "application-x-executable";
        if (raw.indexOf("://") !== -1 || raw.charAt(0) === "/")
            return raw.charAt(0) === "/" ? ("file://" + raw) : raw;
        // steam_icon_<id> is written after startup. The theme list from
        // then is empty, so the png path is the icon that actually paints.
        const fileIcon = DesktopShortcuts.iconFor(raw);
        if (fileIcon.length)
            return fileIcon;

        const names = [];
        const seen = ({});
        root._push(names, seen, raw);
        const entry = root._fromDesktop(raw);
        if (entry) {
            root._push(names, seen, entry.icon);
            root._push(names, seen, entry.startupClass);
            root._push(names, seen, entry.id);
        }

        let best = "";
        let bestScore = -1;
        for (let i = 0; i < names.length; i++) {
            const n = names[i];
            if (n.indexOf("://") !== -1 || n.charAt(0) === "/")
                continue;
            const namedFile = DesktopShortcuts.iconFor(n);
            if (namedFile.length)
                return namedFile;
            if (!Quickshell.hasThemeIcon(n))
                continue;
            const sc = root._score(n);
            const better = sc > bestScore
                || (sc === bestScore && n === n.toLowerCase() && best !== best.toLowerCase());
            if (better) {
                best = n;
                bestScore = sc;
            }
        }
        if (best.length)
            return best;
        return "application-x-executable";
    }
}
