// Official-repo package store. Search/info/install/remove via scripts;
// upgrades stay in Settings → System (Update).
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property bool open: false
    property string categoryId: "discover"
    property string query: ""
    property var results: []
    property var featured: []
    property bool loading: false
    property string mutating: ""
    property string error: ""
    property string log: ""
    property string pendingName: ""
    property string pendingAction: ""
    property string _mode: ""
    property string _mutAction: ""
    readonly property alias categories: catalog.categories
    readonly property alias popular: catalog.popular
    signal notify(string summary, string body)

    StoreCatalog {
        id: catalog
        onLoaded: {
            if (root.open)
                root.reload();
        }
    }

    Timer {
        id: searchDebounce
        interval: Motion.mediumMs
        onTriggered: root._runSearch()
    }

    Process {
        id: proc
        running: false
        stdout: StdioCollector { id: procOut }
        stderr: StdioCollector { id: procErr }
        onExited: (code) => root._procDone(code, procOut.text, procErr.text)
    }

    Process {
        id: mutProc
        running: false
        stdout: SplitParser {
            onRead: line => root._append(line)
        }
        stderr: SplitParser {
            onRead: line => root._append(line)
        }
        onExited: (code) => root._mutDone(code === 0)
    }

    Connections {
        target: Settings
        function onOpenChanged() {
            if (root.open)
                Update.watching = true;
        }
        function onSectionIdChanged() {
            if (root.open)
                Update.watching = true;
        }
    }

    function show() {
        root.open = true;
        Update.watching = true;
        if (!Update.checking && !Update.running)
            Update.refresh();
        root.reload();
    }

    function hide() {
        root.open = false;
        root.cancel();
        if (!Settings.open || Settings.sectionId !== "system")
            Update.watching = false;
    }

    function toggle() {
        if (root.open)
            root.hide();
        else
            root.show();
    }

    function setQuery(text: string) {
        root.query = String(text || "");
        if (root.query.trim().length > 0) {
            searchDebounce.restart();
            return;
        }
        root.reload();
    }

    function setCategory(id: string) {
        root.categoryId = String(id || "discover");
        if (root.query.length > 0)
            root.query = "";
        root.reload();
    }

    function requestInstall(name: string) {
        if (!root._valid(name) || root.mutating.length > 0)
            return;
        root.pendingName = name;
        root.pendingAction = "install";
    }

    function requestRemove(name: string) {
        if (!root._valid(name) || root.mutating.length > 0)
            return;
        root.pendingName = name;
        root.pendingAction = "remove";
    }

    function cancel() {
        root.pendingName = "";
        root.pendingAction = "";
    }

    function confirm() {
        const name = root.pendingName;
        const action = root.pendingAction;
        root.cancel();
        if (!root._valid(name) || (action !== "install" && action !== "remove"))
            return;
        root._mutAction = action;
        root.mutating = name;
        root.error = "";
        root.log = "";
        mutProc.command = [Paths.script("pkg-mutate.sh"), action, name];
        mutProc.running = true;
    }

    function reload() {
        if (root.query.trim().length > 0) {
            root._runSearch();
            return;
        }
        if (root.categoryId === "installed") {
            root._start([Paths.script("pkg-explicit.sh")], "explicit");
            return;
        }
        if (root.categoryId === "discover") {
            root._loadNames(root.popular, "featured");
            return;
        }
        root._loadNames(catalog.packages(root.categoryId), "info");
    }

    function iconFor(id: string): string {
        return catalog.iconFor(id);
    }

    function _valid(name: string): bool {
        return /^[a-z0-9][a-z0-9.+_-]*$/.test(String(name || ""));
    }

    function _loadNames(names, mode: string) {
        const argv = [Paths.script("pkg-info.sh")];
        const list = names || [];
        for (let i = 0; i < list.length; i++) {
            if (root._valid(list[i]))
                argv.push(list[i]);
        }
        if (argv.length < 2) {
            if (mode === "featured")
                root.featured = [];
            else
                root.results = [];
            root.loading = false;
            return;
        }
        root._start(argv, mode);
    }

    function _runSearch() {
        const q = root.query.trim();
        if (!q.length) {
            root.reload();
            return;
        }
        root._start([Paths.script("pkg-search.sh"), q], "search");
    }

    function _start(cmd, mode: string) {
        proc.running = false;
        root._mode = mode;
        root.loading = true;
        root.error = "";
        proc.command = cmd;
        proc.running = true;
    }

    function _rows(text: string) {
        try {
            const parsed = JSON.parse(String(text || "").trim() || "[]");
            return Array.isArray(parsed) ? parsed : [];
        } catch (e) {
            return [];
        }
    }

    function _procDone(code: int, out: string, err: string) {
        if (root._mode === "explicit") {
            root._loadNames(root._rows(out), "info");
            return;
        }
        const rows = root._rows(out);
        if (root._mode === "featured")
            root.featured = rows;
        else
            root.results = rows;
        root.loading = false;
        if (code !== 0 && rows.length === 0) {
            const t = String(err || "").trim();
            if (t.length)
                root.error = t;
        }
    }

    function _append(line: string) {
        const t = String(line || "").trim();
        if (t.length)
            root.log += t + "\n";
    }

    function _mutDone(ok: bool) {
        const name = root.mutating;
        const action = root._mutAction;
        root.mutating = "";
        root._mutAction = "";
        if (!ok) {
            root.error = root.log.trim().length ? root.log.trim() : I18n.t("store.failed");
            root.notify(I18n.t("store.failed"), name);
            return;
        }
        const key = action === "remove" ? "store.doneRemove" : "store.doneInstall";
        root.notify(I18n.t(key, ({ name: name })), "");
        root.reload();
    }

    IpcHandler {
        target: "store"
        function toggle() { root.toggle(); }
        function show() { root.show(); }
        function hide() { root.hide(); }
    }
}
