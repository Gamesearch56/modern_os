// StatusNotifier tray. Owns D-Bus SNI; the bar tray widget and the
// taskbar (apps with no Hyprland window, e.g. Discord closed to tray)
// only read this singleton.
pragma Singleton

import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import "../Commons"

Singleton {
    id: root

    property int _gen: 0

    TrayRoster {
        id: roster
        onChanged: root._gen++
    }

    readonly property var items: {
        void root._gen;
        return roster.list();
    }

    property var dismissed: ({})

    function _key(item: var): string {
        return String(item?.id || item?.title || item?.tooltipTitle || "");
    }

    function dismiss(item: var) {
        const k = root._key(item);
        if (!k.length)
            return;
        const next = Object.assign({}, root.dismissed);
        next[k] = true;
        root.dismissed = next;
        root._gen++;
    }

    function pidsOf(item: var): var {
        const apps = RunningApps.apps || [];
        const out = [];
        const seen = {};
        for (let i = 0; i < apps.length; i++) {
            const app = apps[i];
            if (!RunningApps.matchesTray(app, item))
                continue;
            const pids = app.pids || [];
            for (let p = 0; p < pids.length; p++) {
                const n = Number(pids[p] || 0);
                if (n <= 1 || seen[n])
                    continue;
                seen[n] = true;
                out.push(n);
            }
        }
        return out;
    }

    function _live(item: var): bool {
        return root.pidsOf(item).length > 0;
    }

    function isApp(item: var): bool {
        if (!item)
            return false;
        const cat = item.category;
        if (cat === Category.Hardware || cat === Category.SystemServices)
            return false;
        const title = String(item.title || item.tooltipTitle || "").trim();
        const id = String(item.id || "").trim();
        return title.length > 0 || id.length > 0;
    }

    function _norm(s: string): string {
        return String(s || "").replace(/\.desktop$/i, "").toLowerCase().replace(/[\s._-]+/g, "");
    }

    function _hayFields(toplevel: var): var {
        if (!toplevel)
            return [];
        const ipc = toplevel.lastIpcObject || ({});
        return [
            root._norm(ipc.class),
            root._norm(ipc.initialClass),
            root._norm(toplevel.class),
            root._norm(ipc.title),
            root._norm(toplevel.title)
        ];
    }

    function matchesWindow(item: var, toplevel: var): bool {
        if (!item || !toplevel)
            return false;
        const fields = root._hayFields(toplevel);
        const names = [root._norm(item.title), root._norm(item.tooltipTitle)];
        for (let i = 0; i < names.length; i++) {
            const n = names[i];
            if (n.length < 3)
                continue;
            for (let j = 0; j < fields.length; j++) {
                const f = fields[j];
                if (f.length < 3)
                    continue;
                if (f === n)
                    return true;
                if (n.length >= 5 && (f.indexOf(n) !== -1 || n.indexOf(f) !== -1))
                    return true;
            }
        }
        const idn = root._norm(item.id);
        if (idn.length >= 3) {
            for (let k = 0; k < fields.length; k++) {
                if (fields[k] === idn)
                    return true;
            }
        }
        return false;
    }

    function orphans(windows: var): var {
        void RunningApps.apps;
        void root.dismissed;
        const wins = windows || [];
        const list = root.items;
        const out = [];
        for (let i = 0; i < list.length; i++) {
            const it = list[i];
            if (!root.isApp(it))
                continue;
            const key = root._key(it);
            if (key.length && root.dismissed[key] && !root._live(it))
                continue;
            let hit = false;
            for (let j = 0; j < wins.length; j++) {
                if (root.matchesWindow(it, wins[j])) {
                    hit = true;
                    break;
                }
            }
            if (hit)
                continue;
            if (!root._live(it))
                continue;
            out.push(it);
        }
        return out;
    }

    // Activate can map the window onto the hidden workspace. Raise it
    // once it exists, and try again if the map is still in flight.
    property string _raiseId: ""
    property int _raiseTries: 0

    function _raiseHint(item: var): string {
        const tip = String(item?.tooltipTitle || item?.title || "").trim();
        if (tip.length >= 3)
            return tip;
        return String(item?.id || "").replace(/_status_icon.*$/i, "");
    }

    function activate(item: var) {
        if (item && item.activate)
            item.activate();
        const hint = root._raiseHint(item);
        if (hint.length < 3)
            return;
        root._raiseId = hint;
        root._raiseTries = 0;
        raiseTimer.restart();
    }

    Timer {
        id: raiseTimer
        interval: Motion.extraLongMs
        onTriggered: {
            const id = root._raiseId;
            if (!id.length)
                return;
            if (Hypr.raiseDesktop(id) || root._raiseTries >= 1) {
                root._raiseId = "";
                root._raiseTries = 0;
                return;
            }
            root._raiseTries++;
            raiseTimer.restart();
        }
    }
}
