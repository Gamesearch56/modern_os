// Places that are not the folder listing: home, XDG folders, recent
// files, network mounts, and mounting a removable disk.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property var dirs: []
    property var recent: []
    property var mounts: []
    property var _known: ({})
    property string _kind: ""
    property string _out: ""
    property var _queue: []
    property var _job: null

    signal mounted(string path)

    function reload() {
        root._enqueue(["dirs"], "dirs");
        root._enqueue(["recent"], "recent");
        root._enqueue(["mounts"], "mounts");
    }

    function reloadRecent() {
        root._enqueue(["recent"], "recent");
    }

    function record(path: string) {
        root._enqueue(["record", path], "record");
    }

    function clearRecent() {
        root._enqueue(["clear"], "clear");
    }

    function mount(name: string) {
        root._enqueue(["mount", name], "mount");
    }

    function openTerminal(path: string) {
        const id = String(Config.apps.defaults.terminal || "kitty").replace(/\.desktop$/, "").toLowerCase();
        let cmd = ["kitty", "--working-directory", path];
        if (id.indexOf("foot") !== -1)
            cmd = ["foot", "--working-directory", path];
        else if (id.indexOf("alacritty") !== -1)
            cmd = ["alacritty", "--working-directory", path];
        else if (id.indexOf("wezterm") !== -1)
            cmd = ["wezterm", "start", "--cwd", path];
        Quickshell.execDetached(cmd);
    }

    function note(place: string) {
        if (place === "recent") root.reloadRecent();
        else if (place === "trash") FilesTrash.refresh();
        else if (place === "network") root.reload();
        else if (place === "favorites") root.prune();
    }

    function prune() {
        const cur = Config.files.favorites || [];
        if (cur.length)
            root._enqueue(["present"].concat(cur), "present");
    }

    function retarget(args: var, raw: string) {
        const cmd = args || [];
        const op = String(cmd[0] || "");
        let made = [];
        try {
            const info = JSON.parse(String(raw || ""));
            if (info && Array.isArray(info.paths))
                made = info.paths;
            else if (info && info.path)
                made = [info.path];
        } catch (e) {
            made = [];
        }
        const cur = (Config.files.favorites || []).slice();
        if (cur.length && op === "delete")
            root._save(cur, root._without(cur, cmd.slice(1)));
        else if (cur.length && op === "move")
            root._save(cur, root._moved(cur, cmd.slice(2), String(cmd[1] || ""), made));
        else if (cur.length && op === "rename")
            root._save(cur, root._renamed(cur, String(cmd[1] || ""), String(cmd[2] || "")));
        root.reloadRecent();
    }

    function drop(paths: var) {
        const cur = (Config.files.favorites || []).slice();
        root._save(cur, root._without(cur, paths || []));
        root.reloadRecent();
    }

    function renameOne(before: string, after: string) {
        const cur = (Config.files.favorites || []).slice();
        const next = [];
        const old = String(before || "");
        const made = String(after || "");
        for (let i = 0; i < cur.length; i++) {
            const path = String(cur[i] || "");
            if (path === old)
                next.push(made);
            else if (old.length > 1 && path.indexOf(old + "/") === 0)
                next.push(made + path.slice(old.length));
            else
                next.push(path);
        }
        root._save(cur, next);
        root.reloadRecent();
    }

    function _without(cur: var, sources: var): var {
        const next = [];
        const from = sources || [];
        for (let i = 0; i < cur.length; i++) {
            const path = String(cur[i] || "");
            let gone = false;
            for (let k = 0; k < from.length; k++) {
                const src = String(from[k] || "");
                if (src.length > 1 && (path === src || path.indexOf(src + "/") === 0))
                    gone = true;
            }
            if (!gone)
                next.push(path);
        }
        return next;
    }

    function _moved(cur: var, sources: var, dest: string, made: var) {
        const landed = made || [];
        if (dest.charAt(0) !== "/" && !landed.length)
            return cur;
        const next = [];
        const from = sources || [];
        for (let i = 0; i < cur.length; i++) {
            const path = String(cur[i] || "");
            let mapped = path;
            for (let k = 0; k < from.length; k++) {
                const src = String(from[k] || "");
                let base = k < landed.length ? String(landed[k] || "") : "";
                if (base.charAt(0) !== "/") {
                    const leaf = src.slice(src.lastIndexOf("/") + 1);
                    base = dest === "/" ? "/" + leaf : dest + "/" + leaf;
                }
                if (src.length > 1 && path === src) {
                    mapped = base;
                    break;
                }
                if (src.length > 1 && path.indexOf(src + "/") === 0) {
                    mapped = base + path.slice(src.length);
                    break;
                }
            }
            next.push(mapped);
        }
        return next;
    }

    function _renamed(cur: var, oldPath: string, name: string) {
        if (oldPath.charAt(0) !== "/" || !name.length || name.indexOf("/") !== -1)
            return cur;
        const slash = oldPath.lastIndexOf("/");
        const made = (slash > 0 ? oldPath.slice(0, slash) : "") + "/" + name;
        const next = [];
        for (let i = 0; i < cur.length; i++) {
            const path = String(cur[i] || "");
            if (path === oldPath)
                next.push(made);
            else if (path.indexOf(oldPath + "/") === 0)
                next.push(made + path.slice(oldPath.length));
            else
                next.push(path);
        }
        return next;
    }

    function _save(prev: var, next: var) {
        if (prev.length === next.length) {
            let same = true;
            for (let i = 0; i < prev.length; i++) {
                if (prev[i] !== next[i])
                    same = false;
            }
            if (same)
                return;
        }
        ConfigWrite.set("files.favorites", next);
    }

    function toggleFavorite(path: string) {
        const cur = (Config.files.favorites || []).slice();
        const at = cur.indexOf(path);
        if (at >= 0)
            cur.splice(at, 1);
        else
            cur.push(path);
        ConfigWrite.set("files.favorites", cur);
        root.prune();
    }

    function favorite(path: string): bool {
        return (Config.files.favorites || []).indexOf(path) >= 0;
    }

    function favoriteRows(paths: var): var {
        const list = paths || [];
        const known = root._known || {};
        const out = [];
        for (let i = 0; i < list.length; i++) {
            const path = String(list[i] || "");
            if (path.charAt(0) !== "/")
                continue;
            if (known[path]) { out.push(known[path]); continue; }
            const name = path.slice(path.lastIndexOf("/") + 1) || I18n.t("files.path.root");
            out.push({ name: name, path: path, dir: false, size: -1, mtime: 0, created: 0, kind: "file", readable: true });
        }
        return out;
    }

    function _enqueue(args: var, kind: string) {
        const q = root._queue.slice();
        q.push({ args: args, kind: kind });
        root._queue = q;
        root._pump();
    }

    function _pump() {
        if (proc.running || !root._queue.length)
            return;
        const q = root._queue.slice();
        root._job = q.shift();
        root._queue = q;
        root._kind = root._job.kind;
        root._out = "";
        proc.command = [Paths.script("files-places.sh")].concat(root._job.args);
        proc.running = true;
    }

    function _keep(rows) {
        const paths = [];
        const known = {};
        for (let i = 0; i < (rows || []).length; i++) {
            const path = String((rows[i] && rows[i].path) || "");
            if (path.charAt(0) !== "/") continue;
            paths.push(path);
            known[path] = rows[i];
        }
        root._known = known;
        root._save((Config.files.favorites || []).slice(), paths);
    }

    function _apply() {
        let rows = [];
        try { rows = JSON.parse(root._out || "[]"); } catch (e) { rows = []; }
        if (root._kind === "dirs") root.dirs = rows;
        else if (root._kind === "recent") root.recent = rows;
        else if (root._kind === "mounts") root.mounts = rows;
        else if (root._kind === "present" && root._out.length) root._keep(rows);
        else if (root._kind === "mount") {
            const path = String((rows && rows.path) || "");
            if (path.length) root.mounted(path);
        } else if (root._kind === "record" || root._kind === "clear") root.reloadRecent();
        root._job = null;
        root._pump();
    }

    Process {
        id: proc
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._out = String(this.text || "")
        }
        onExited: root._apply()
    }
}
