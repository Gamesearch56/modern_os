// Desktop apps whose process is alive with no Hyprland window and no
// StatusNotifier item (Discord on Wayland close-to-tray).
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property var apps: []

    Component.onCompleted: root.refresh()

    Process {
        id: proc
        command: [Paths.script("running-apps.sh")]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parse(this.text)
        }
    }

    function refresh() {
        if (proc.running)
            return;
        proc.running = true;
    }

    function _parse(text: string) {
        const raw = String(text || "").trim();
        if (!raw.length) {
            root.apps = [];
            return;
        }
        try {
            const data = JSON.parse(raw);
            root.apps = Array.isArray(data) ? data : [];
        } catch (e) {
            Logger.warn("RunningApps", String(e));
            root.apps = [];
        }
    }

    function _norm(s: string): string {
        return String(s || "").replace(/\.desktop$/i, "").toLowerCase().replace(/[\s._-]+/g, "");
    }

    function _tokens(app: var): var {
        return [
            root._norm(app?.class),
            root._norm(app?.id),
            root._norm(app?.name),
            root._norm(app?.icon)
        ];
    }

    Timer {
        id: afterKill
        interval: 250
        repeat: false
        onTriggered: root.refresh()
    }

    function _skipName(n: string): bool {
        const s = String(n || "").toLowerCase();
        if (!s.length || s.indexOf("/") !== -1 || s.indexOf("application-x-") === 0)
            return true;
        if (s.length < 3)
            return true;
        // Shared runtimes — kill by PID tree only, never by name.
        const generic = {
            "env": true, "sh": true, "bash": true, "flatpak": true,
            "electron": true, "java": true, "python": true, "python3": true,
            "node": true, "wine": true, "wine64": true, "wineserver": true,
            "steamwebhelper": true, "gamemoderun": true
        };
        return !!generic[s];
    }

    function _namesOf(entry: var): var {
        const out = [];
        const seen = {};
        function add(raw) {
            const t = String(raw || "").replace(/\.desktop$/i, "").trim().toLowerCase();
            if (root._skipName(t) || t.length < 3 || seen[t])
                return;
            seen[t] = true;
            out.push(t);
            const w = t.split(/[\s._-]+/)[0];
            if (w.length >= 3 && !seen[w] && !root._skipName(w)) {
                seen[w] = true;
                out.push(w);
            }
            const stem = t.endsWith("-launcher") ? t.slice(0, -9) : "";
            if (stem.length >= 3 && !seen[stem] && !root._skipName(stem)) {
                seen[stem] = true;
                out.push(stem);
            }
        }
        add(entry?.desktopId);
        add(entry?.cls);
        add(entry?.icon);
        if (entry?.kind === "tray" || entry?.kind === "process")
            add(entry?.title);
        return out;
    }

    function killEntry(entry: var) {
        if (!entry)
            return;
        const args = [Paths.script("kill-app.sh")];
        const seenPid = {};
        function addPid(v) {
            const n = Number(v || 0);
            if (n <= 1 || seenPid[n])
                return;
            seenPid[n] = true;
            args.push("--pid");
            args.push(String(n));
        }
        addPid(entry.pid);
        const extra = entry.pids || [];
        for (let i = 0; i < extra.length; i++)
            addPid(extra[i]);
        const names = root._namesOf(entry);
        for (let j = 0; j < names.length; j++) {
            args.push("--name");
            args.push(names[j]);
        }
        if (args.length < 3)
            return;
        Quickshell.execDetached(args);
        afterKill.restart();
    }

    function _hits(needles: var, fields: var): bool {
        for (let i = 0; i < needles.length; i++) {
            const n = needles[i];
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
        return false;
    }

    function matchesWindow(app: var, toplevel: var): bool {
        if (!app || !toplevel)
            return false;
        const ipc = toplevel.lastIpcObject || ({});
        const fields = [
            root._norm(ipc.class),
            root._norm(ipc.initialClass),
            root._norm(toplevel.class),
            root._norm(ipc.title),
            root._norm(toplevel.title)
        ];
        return root._hits(root._tokens(app), fields);
    }

    function matchesTray(app: var, item: var): bool {
        if (!app || !item)
            return false;
        const fields = [
            root._norm(item.title),
            root._norm(item.tooltipTitle),
            root._norm(item.id)
        ];
        return root._hits(root._tokens(app), fields);
    }

    function hidden(windows: var, trayItems: var): var {
        const wins = windows || [];
        const tray = trayItems || [];
        const list = root.apps || [];
        const out = [];
        for (let i = 0; i < list.length; i++) {
            const app = list[i];
            if (!app)
                continue;
            let skip = false;
            for (let w = 0; w < wins.length; w++) {
                if (root.matchesWindow(app, wins[w])) {
                    skip = true;
                    break;
                }
            }
            if (skip)
                continue;
            for (let t = 0; t < tray.length; t++) {
                if (root.matchesTray(app, tray[t])) {
                    skip = true;
                    break;
                }
            }
            if (!skip)
                out.push(app);
        }
        return out;
    }
}
