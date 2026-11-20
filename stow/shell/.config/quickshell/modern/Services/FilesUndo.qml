pragma Singleton
// Permanent delete is not recorded: those bytes are gone. The last 40 steps stay.
import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property bool playing: false
    property var undoStack: []
    property var redoStack: []
    property string _side: ""
    property var _entry: null
    property int _limit: 40

    function note(cmd: var, raw: string) {
        if (root.playing)
            return;
        const op = String((cmd || [])[0] || "");
        let info = ({});
        try { info = JSON.parse(String(raw || "{}")); } catch (e) { return; }
        if (op === "rename")
            root._moved(String(cmd[1] || ""), String(info.path || ""));
        else if (op === "move")
            root._pairs(cmd.slice(2), info.paths || []);
        else if (op === "place")
            root._placed(String(cmd[1] || ""), info);
        else if (op === "copy" || op === "mkdir" || op === "touch") {
            const made = op === "copy" ? (info.paths || []) : [String(info.path || "")];
            const items = [];
            for (let i = 0; i < made.length; i++) {
                if (made[i])
                    items.push({ path: String(made[i]), name: "" });
            }
            if (items.length)
                root._push({ kind: "presence", where: "paths", items: items });
        }
    }

    function noteTrash(args: var, raw: string) {
        if (root.playing)
            return;
        const op = String((args || [])[0] || "");
        let info = ({});
        try { info = JSON.parse(String(raw || "{}")); } catch (e) { return; }
        if (op === "move") {
            const rows = info.items || [];
            const items = [];
            for (let i = 0; i < rows.length; i++) {
                const path = String(rows[i].path || "");
                const name = String(rows[i].name || "");
                if (path && name)
                    items.push({ path: path, name: name });
            }
            if (items.length)
                root._push({ kind: "presence", where: "trash", items: items });
        } else if (op === "restore") {
            const path = String(info.path || "");
            const name = String(args[1] || "");
            if (path && name)
                root._push({ kind: "presence", where: "paths", items: [{ path: path, name: name }] });
        }
    }

    function noteAccess(job: var, raw: string) {
        if (root.playing || !job || !job.extra || !job.extra.snap)
            return;
        const extra = job.extra;
        const snap = extra.snap;
        let info = ({});
        try { info = JSON.parse(String(raw || "{}")); } catch (e) { info = ({}); }
        const from = String(snap.path || "");
        const to = String(info.path || from);
        const modeFrom = String(snap.bits || "");
        const modeTo = extra.bits ? String(extra.bits) : modeFrom;
        const ownerFrom = String(snap.owner || "");
        const ownerTo = extra.owner ? String(extra.owner) : ownerFrom;
        const groupFrom = String(snap.group || "");
        const groupTo = extra.group ? String(extra.group) : groupFrom;
        if (!from || (from === to && modeFrom === modeTo && ownerFrom === ownerTo && groupFrom === groupTo))
            return;
        root._push({
            kind: "edit", from: from, to: to,
            modeFrom: modeFrom, modeTo: modeTo,
            ownerFrom: ownerFrom, ownerTo: ownerTo,
            groupFrom: groupFrom, groupTo: groupTo
        });
    }

    function undo() { root._start("undo"); }
    function redo() { root._start("redo"); }

    function _placed(raw: string, info: var) {
        let plan = ({});
        try { plan = JSON.parse(raw || "{}"); } catch (e) { return; }
        const items = plan.items || [];
        const sources = [];
        for (let i = 0; i < items.length; i++)
            sources.push(String(items[i].src || ""));
        const covered = root._covered(info);
        if (plan.op === "move")
            root._pairs(sources, (info && info.paths) || [], covered);
        else if (plan.op === "copy") {
            const made = (info && info.paths) || [];
            const rows = [];
            for (let i = 0; i < made.length; i++) {
                if (made[i])
                    rows.push({ path: String(made[i]), name: "" });
            }
            if (rows.length)
                root._push({ kind: "presence", where: "paths", items: rows, covered: covered });
        }
    }

    function noteRoute(from: var, to: var) {
        if (root.playing) return;
        const left = root._spot(from);
        const right = root._spot(to);
        if (!left.place || (left.place === right.place && left.path === right.path)) return;
        root._push({ kind: "route", from: left, to: right });
    }

    function noteClip(mode: string) {
        if (root.playing) return;
        const after = (Files.selected || []).map(row => String(row || "")).filter(row => row.length > 0);
        if (!after.length) return;
        const before = { mode: String(Files.clipboardMode || ""), paths: (Files.clipboard || []).slice() };
        if (before.mode === mode && root._listSame(before.paths, after)) return;
        Files.clipboardMode = mode;
        Files.clipboard = after;
        root._push({ kind: "clip", before: before, after: { mode: mode, paths: after } });
    }

    function _moved(from: string, to: string) {
        if (from && to && from !== to)
            root._push({ kind: "move", pairs: [{ from: from, to: to }] });
    }

    function _pairs(sources: var, made: var, covered: var) {
        const pairs = [];
        const rows = sources || [];
        const landed = made || [];
        if (rows.length !== landed.length)
            return;
        for (let i = 0; i < rows.length; i++) {
            const from = String(rows[i] || "");
            const to = String(landed[i] || "");
            if (from && to && from !== to) pairs.push({ from: from, to: to });
        }
        if (pairs.length)
            root._push({ kind: "move", pairs: pairs, covered: covered || [] });
    }

    function _covered(info: var): var {
        return ((info && info.covered) || []).filter(row => row && row.path && row.name).map(row => ({ path: String(row.path), name: String(row.name) }));
    }

    function _spot(row: var): var {
        const spot = row || {};
        return { path: String(spot.path || ""), place: String(spot.place || ""), pick: (spot.pick || []).map(item => String(item || "")).filter(item => item.length > 0) };
    }

    function _listSame(left: var, right: var): bool {
        const a = left || []; const b = right || [];
        if (a.length !== b.length) return false;
        for (let i = 0; i < a.length; i++) if (String(a[i] || "") !== String(b[i] || "")) return false;
        return true;
    }

    function _applyClip(row: var) {
        const clip = row || {};
        Files.clipboardMode = String(clip.mode || "");
        Files.clipboard = (clip.paths || []).map(item => String(item || "")).filter(item => item.length > 0);
    }

    function _push(entry: var) {
        const stack = root.undoStack.slice();
        stack.push(entry);
        if (stack.length > root._limit)
            stack.shift();
        root.undoStack = stack;
        root.redoStack = [];
    }

    function _start(side: string) {
        if (root.playing || Files.busy || FilesTrash.busy || FilesAccess.busy)
            return;
        const stack = (side === "undo" ? root.undoStack : root.redoStack).slice();
        if (!stack.length)
            return;
        root._entry = stack.pop();
        if (side === "undo")
            root.undoStack = stack;
        else
            root.redoStack = stack;
        root._side = side;
        const kind = String((root._entry && root._entry.kind) || "");
        if (kind === "route" || kind === "clip") {
            root.playing = true;
            if (kind === "route")
                FilesHistory.restore(side === "undo" ? root._entry.from : root._entry.to);
            else
                root._applyClip(side === "undo" ? root._entry.before : root._entry.after);
            root.playing = false;
            root._done(root._entry);
            return;
        }
        root.playing = true;
        proc.command = [Paths.script("files-ops.sh"), "apply", JSON.stringify({ side: side, entry: root._entry })];
        proc.running = true;
    }

    function _keep() {
        const stack = (root._side === "undo" ? root.undoStack : root.redoStack).slice();
        stack.push(root._entry);
        if (root._side === "undo")
            root.undoStack = stack;
        else
            root.redoStack = stack;
    }

    function _done(entry: var) {
        const stack = (root._side === "undo" ? root.redoStack : root.undoStack).slice();
        stack.push(entry);
        if (root._side === "undo")
            root.redoStack = stack;
        else
            root.undoStack = stack;
        if (entry.kind === "route" || entry.kind === "clip")
            return;
        root._follow(entry);
        const pick = [];
        if (entry.kind === "presence" && entry.where === "paths") {
            for (let i = 0; i < entry.items.length; i++)
                pick.push(entry.items[i].path);
        } else if (entry.kind === "move") {
            for (let i = 0; i < entry.pairs.length; i++)
                pick.push(root._side === "undo" ? entry.pairs[i].from : entry.pairs[i].to);
        } else if (entry.kind === "edit")
            pick.push(root._side === "undo" ? entry.from : entry.to);
        if (pick.length)
            Files.selected = pick;
        Files.refresh();
        FilesTrash.refresh();
    }

    function _follow(entry: var) {
        if (entry.kind === "move") {
            for (let i = 0; i < entry.pairs.length; i++) {
                const pair = entry.pairs[i];
                if (root._side === "undo")
                    FilesPlaces.renameOne(pair.to, pair.from);
                else
                    FilesPlaces.renameOne(pair.from, pair.to);
            }
        } else if (entry.kind === "edit" && entry.from !== entry.to) {
            if (root._side === "undo")
                FilesPlaces.renameOne(entry.to, entry.from);
            else
                FilesPlaces.renameOne(entry.from, entry.to);
        } else if (entry.kind === "presence" && entry.where === "trash") {
            const paths = [];
            for (let i = 0; i < entry.items.length; i++)
                paths.push(entry.items[i].path);
            FilesPlaces.drop(paths);
        }
    }

    Process {
        id: proc
        running: false
        stdout: StdioCollector { id: outBuf }
        stderr: StdioCollector { id: errBuf }
        onExited: (code) => {
            const side = root._side;
            root.playing = false;
            if (code !== 0) {
                root._keep();
                Files.failed(String(errBuf.text || "").trim() || "refused");
                return;
            }
            let entry = root._entry;
            try { entry = JSON.parse(String(outBuf.text || "")); } catch (e) { entry = root._entry; }
            root._side = side;
            root._done(entry);
        }
    }
}
