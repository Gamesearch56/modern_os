pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

// Shipped text editor, image viewer, and video player.
// install/manifests/default-apps.json is the list. A non-empty
// apps.defaults value in config.json wins; Settings writes that file only.
Singleton {
    id: root

    property var _roles: ({})

    function _item(role: string): var {
        const roles = root._roles || ({});
        const item = roles[role];
        return item || null;
    }

    function desktop(role: string): string {
        const item = root._item(role);
        return item ? String(item.desktop || "") : "";
    }

    // Picker pins: the desktop id plus its short name, so a NoDisplay
    // handler for the shipped app still appears.
    function ids(role: string): var {
        const id = root.desktop(role);
        if (!id.length)
            return [];
        const tail = id.replace(/\.desktop$/, "").split(".").pop();
        if (tail && tail !== id)
            return [id, tail];
        return [id];
    }

    // Last-resort argv when no desktop entry is installed. An exec
    // override wins over the package name.
    function launchArgv(role: string): var {
        const item = root._item(role);
        if (!item)
            return [];
        const exec = item.exec;
        if (exec && exec.length)
            return exec;
        const pkgs = item.packages;
        if (pkgs && pkgs.length)
            return [String(pkgs[0])];
        return [];
    }

    FileView {
        id: file
        path: Paths.repo + "/install/manifests/default-apps.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onPathChanged: reload()
        onLoaded: {
            try {
                root._roles = JSON.parse(String(text() || "").trim() || "{}") || ({});
            } catch (e) {
                root._roles = ({});
                Logger.warn("DefaultApps", "manifest is not valid JSON");
            }
        }
        onLoadFailed: root._roles = ({})
    }

    // 1 can open, 0 cannot, -1 still unknown. Cached by extension so a
    // hover does not ask again for every file of that type.
    property var _open: ({})
    property int stamp: 0
    property string _probe: ""
    property var _wait: []

    function openable(entry): int {
        if (!entry)
            return 0;
        if (entry.readable === false || entry.canRead === false)
            return 0;
        if (entry.dir)
            return 1;
        const key = root._key(entry.path);
        if (root._open[key] === true)
            return 1;
        if (root._open[key] === false)
            return 0;
        return -1;
    }

    function askOpen(path: string) {
        const key = root._key(path);
        if (!key.length || root._open[key] === true || root._open[key] === false)
            return;
        const wait = root._wait || [];
        for (let i = 0; i < wait.length; i++) {
            if (wait[i].key === key)
                return;
        }
        const next = wait.slice();
        next.push({ key: key, path: String(path || "") });
        root._wait = next;
        root._pump();
    }

    function _key(path: string): string {
        const base = String(path || "").split("/").pop();
        const dot = base.lastIndexOf(".");
        if (dot <= 0)
            return "path:" + String(path || "");
        return "ext:" + base.slice(dot + 1).toLowerCase();
    }

    function _pump() {
        if (probe.running || !(root._wait || []).length)
            return;
        const wait = root._wait.slice();
        const job = wait.shift();
        root._wait = wait;
        root._probe = String(job.key || "");
        probe.command = [Paths.script("files-open.sh"), "--can", String(job.path || "")];
        probe.running = true;
    }

    Process {
        id: probe
        running: false
        onExited: (code) => {
            const bag = Object.assign({}, root._open);
            bag[root._probe] = code === 0;
            root._open = bag;
            root.stamp += 1;
            root._pump();
        }
    }
}
