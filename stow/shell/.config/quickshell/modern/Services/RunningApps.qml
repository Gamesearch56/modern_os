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
