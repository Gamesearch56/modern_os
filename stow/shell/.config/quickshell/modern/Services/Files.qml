pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"
Singleton {
    id: root
    property bool open: false
    property string path: Paths.home
    property var entries: []
    property var selected: []
    property var _cmd: []
    property string sortKey: "name"
    property bool sortDesc: true
    property bool foldersFirst: true
    property bool showHidden: false
    property bool showSize: true
    property bool showCreated: true
    property bool showModified: true
    property bool showType: true
    property string view: "grid"
    property string hoverPath: ""
    property string place: "folder"
    property string clipboardMode: ""
    property var clipboard: []
    property string renaming: ""
    property bool menuOpen: false
    property int _cover: 0
    readonly property bool covered: root._cover > 0 || root.menuOpen
    property string menuKind: ""
    property string menuPath: ""
    property string menuName: ""
    property real menuX: 0
    property real menuY: 0
    property bool confirming: false
    property string confirmKind: ""
    property bool naming: false
    property string namingKind: ""
    property bool propertiesOpen: false
    property bool _holdSelect: false
    property bool searchOpen: false
    property bool locationOpen: false
    property bool typing: false
    property bool busy: false
    property string error: ""
    property string kept: ""
    property bool _holdOpen: false
    signal failed(string reason)
    signal openedFile(string path)
    signal listed()
    function show(raw: string) {
        root._readConfig();
        root.open = true;
        const path = root._local(raw);
        if (path.length)
            root._enqueue(["stat", path], "open");
        else
            root._openAt(root.path || root._resume);
        if (!Quickshell.env("MODERN_FILE_WINDOW"))
            Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "title:modern.files"]);
    }
    function reveal(raw: string) {
        root._holdOpen = true;
        root.show(raw);
    }
    function _local(raw: string): string {
        let path = String(raw || "").trim();
        if (path.indexOf("file://") !== 0) return path;
        try { return decodeURIComponent(path.slice(7)); } catch (e) { return path.slice(7); }
    }
    function hide() {
        root.menuOpen = false; root._cover = 0; root.propertiesOpen = false; root.confirming = false; root.naming = false; root.open = false;
    }
    function toggle() { if (root.open) root.hide(); else root.show(""); }
    function _pick(out: string) {
        try { const paths = JSON.parse(out || "{}").paths; if (paths && paths.length) root.selected = paths; }
        catch (e) { return; }
    }
    function _readConfig() {
        const files = Config.files;
        root.sortKey = String(files.sortKey || "name");
        root.sortDesc = files.sortDesc !== false;
        root.foldersFirst = files.foldersFirst !== false;
        root.showHidden = files.showHidden === true;
        root.showSize = files.showSize !== false;
        root.showCreated = files.showCreated !== false;
        root.showModified = files.showModified !== false;
        root.showType = files.showType !== false;
        root.view = String(files.view || "grid");
    }
    function _spot() {
        return { path: root.path, place: root.place, pick: (root.selected || []).slice() };
    }
    function _arrive(kind: string, folder: string, pick: var) {
        const place = String(kind || "folder");
        root.kept = root.path;
        root.place = place;
        root.renaming = "";
        root.selected = pick && pick.slice ? pick.slice() : [];
        if (place !== "folder") {
            const keep = String(folder || "");
            if (keep.charAt(0) === "/")
                root.path = keep;
            ops.cancelLists();
            root.busy = false;
            FilesPlaces.note(place);
            return;
        }
        const next = String(folder || "");
        if (next.charAt(0) !== "/")
            return;
        root.path = next;
        root.refresh();
    }
    function go(folder: string, push: bool, pick: var) { FilesHistory.openFolder(folder, push === true, pick); } function showPlace(kind: string) { FilesHistory.openPlace(kind); }
    function back() { FilesHistory.travel(true); } function forward() { FilesHistory.travel(false); } function up() { FilesHistory.up(); } function home() { root.go(Paths.home, true); }
    function cover(up: bool) { root._cover = Math.max(0, root._cover + (up ? 1 : -1)); }
    property string _resume: ""
    function _openAt(folder: string) {
        if (!folder.length) root.go(Paths.home, false);
        else if (folder !== root.path) root.go(folder, false);
        else if (root.place === "folder") root.refresh();
    }
    function refresh() {
        if (!root.path.length) return;
        ops.cancelLists();
        root._enqueue([
            "list", root.path,
            root.showHidden ? "1" : "0",
            root.sortKey,
            root.sortDesc ? "1" : "0",
            root.foldersFirst ? "1" : "0"
        ], "list");
    }
    function setSort(key: string, desc: bool, folders: bool) {
        root.sortKey = key;
        root.sortDesc = desc;
        root.foldersFirst = folders;
        ConfigWrite.set("files.sortKey", key);
        ConfigWrite.set("files.sortDesc", desc);
        ConfigWrite.set("files.foldersFirst", folders);
        root.refresh();
    }
    function setDetail(key: string, on: bool) {
        const name = "show" + key.charAt(0).toUpperCase() + key.slice(1);
        root[name] = on;
        ConfigWrite.set("files." + name, on);
    }
    function setView(mode: string) {
        root.view = mode; root.hoverPath = "";
        ConfigWrite.set("files.view", mode);
    }
    function toggleHidden() {
        root.showHidden = !root.showHidden;
        ConfigWrite.set("files.showHidden", root.showHidden);
        root.refresh();
    }
    function click(file: string, extra: bool) {
        if (!extra) { root.selected = [file]; return; }
        const cur = root.selected.slice();
        const at = cur.indexOf(file);
        if (at >= 0) cur.splice(at, 1); else cur.push(file);
        root.selected = cur;
    }
    function selectAll() {
        root.selected = (root.entries || []).filter(row => row.readable !== false && row.canRead !== false).map(row => row.path);
    }
    function clearSelection() { root.selected = []; }
    function copy() { FilesUndo.noteClip("copy"); }
    function cut() { FilesUndo.noteClip("cut"); }
    function paste(into: string) {
        let dest = String(into || "");
        if (dest.charAt(0) !== "/")
            dest = root.place === "folder" ? String(root.path || "") : "";
        const clip = (root.clipboard || []).slice();
        if (!clip.length || dest.charAt(0) !== "/")
            return;
        if (clip.indexOf(dest) >= 0)
            dest = dest.slice(0, Math.max(dest.lastIndexOf("/"), 1));
        const moving = root.clipboardMode === "cut";
        if (dest !== root.path || root.place !== "folder")
            root.go(dest, true);
        FilesConflict.place(moving ? "move" : "copy", dest, clip);
    }
    function askName(kind: string) {
        if (!root.path.length || root.place !== "folder")
            return;
        root.namingKind = kind === "file" ? "file" : "dir";
        root.naming = true;
    }
    function create(kind: string, name: string) {
        const leaf = String(name || "").trim();
        if (!leaf.length || leaf === "." || leaf === ".." || leaf.indexOf("/") !== -1 || !root.path.length)
            return;
        root.naming = false;
        root.selected = [root.path === "/" ? "/" + leaf : root.path + "/" + leaf];
        root._enqueue([kind === "file" ? "touch" : "mkdir", root.path, leaf], "mutate");
    }
    function renameTo(file: string, name: string) {
        root.renaming = "";
        root._enqueue(["rename", file, name], "mutate");
    }
    function removeSelected() {
        if (!root.selected.length)
            return;
        root._enqueue(["delete"].concat(root.selected), "mutate");
        root.selected = [];
    }
    function openMenu(kind: string, folder: string, name: string, px: real, py: real) {
        const at = String(folder || "");
        root.menuKind = kind; root.menuPath = at.charAt(0) === "/" ? at : ""; root.menuName = name || "";
        root.menuX = px || 0; root.menuY = py || 0; root.menuOpen = true;
    }
    function ask(kind: string) { root.confirmKind = kind; root.confirming = true; }
    function _enqueue(args: var, kind: string) {
        if (kind === "mutate") root._cmd = args;
        root.busy = true; ops.enqueue(args, kind);
    }
    function _finish(kind: string, code: int, out: string, err: string) {
        root.busy = false;
        if (code !== 0) {
            root._holdOpen = false;
            root.error = err || "refused";
            Logger.warn("Files", String(kind || "op") + ": " + root.error);
            if (kind === "list" && root.error === "denied") {
                const entry = FilesHistory.reject();
                if (entry) {
                    root.place = String(entry.place || "folder");
                    root.path = String(entry.path || root.kept);
                    root.selected = entry.pick && entry.pick.slice ? entry.pick.slice() : [];
                } else
                    root.path = root.kept;
            } else if (kind === "mutate")
                root.refresh();
            if (kind === "mutate" && root.error === "exists" && FilesConflict.taken(root._cmd))
                return;
            root.failed(root.error);
            return;
        }
        if (kind === "list") {
            try { root.entries = JSON.parse(out || "[]"); } catch (e) { root.entries = []; }
            root.listed();
            if (FilesHistory.placeReady && root.place === "folder" && root.path.charAt(0) === "/" && !Quickshell.env("MODERN_FILE_WINDOW"))
                placeFile.setText(root.path + "\n");
        } else if (kind === "open")
            root._opened(out);
        else if (kind === "mutate") { FilesPlaces.retarget(root._cmd, out); root._pick(out); FilesUndo.note(root._cmd, out); FilesConflict.done(root._cmd, out); root.refresh(); }
    }
    function _opened(text: string) {
        let info = null;
        try { info = JSON.parse(text || "{}"); } catch (e) { root._holdOpen = false; return; }
        if (!info || !info.path)
            return;
        const hold = root._holdOpen;
        root._holdOpen = false;
        if (info.dir && !info.link) {
            root.go(info.path, true);
            return;
        }
        const slash = info.path.lastIndexOf("/");
        const parent = slash > 0 ? info.path.slice(0, slash) : "/";
        if (root.path !== parent)
            root.go(parent, true);
        root.selected = [info.path];
        if (hold || !info.canRead)
            return;
        Quickshell.execDetached([Paths.script("files-open.sh"), info.path]);
        root.openedFile(info.path);
    }
    FileView {
        id: placeFile
        blockLoading: true
        path: Quickshell.env("HOME") + "/.local/state/modern/files-place"
        printErrors: false
        onLoaded: FilesHistory.notePlace(text(), true)
        onLoadFailed: FilesHistory.notePlace("", true)
    }
    // Reload opens home. Wait until this read finishes before saving again.
    Component.onCompleted: FilesHistory.notePlace(placeFile.text(), false)
    FilesOps {
        id: ops
        onDone: (kind, code, out, err) => root._finish(kind, code, out, err)
    }
    IpcHandler {
        target: "files"
        function open(target: string) { root.show(String(target || "")); }
        function reveal(target: string) { root.reveal(String(target || "")); }
        function toggle() { root.toggle(); }
    }
}
