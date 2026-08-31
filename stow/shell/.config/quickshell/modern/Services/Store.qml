// Official-repo package store. Search/info via scripts; mutate is
// StoreMutate (pkexec pacman). Upgrades stay in Settings → System.
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
    property var sections: []
    property bool loading: false
    property string _mode: ""
    readonly property alias categories: catalog.categories
    readonly property alias popular: catalog.popular
    readonly property alias pendingName: mutate.pendingName
    readonly property alias pendingAction: mutate.pendingAction
    readonly property alias mutating: mutate.mutating
    readonly property alias mutAction: mutate.mutAction
    readonly property alias errorKey: mutate.errorKey
    readonly property alias lastName: mutate.lastName
    readonly property alias log: mutate.log
    readonly property alias authWait: mutate.authWait
    signal notify(string summary, string body)

    StoreCatalog {
        id: catalog
        onLoaded: {
            if (root.open)
                root.reload();
        }
    }

    StoreMutate {
        id: mutate
        onNotify: (summary, body) => root.notify(summary, body)
        onFinished: (ok) => {
            if (!ok)
                return;
            try {
                root.reload();
            } catch (e) {
                Logger.error("Store", String(e));
            }
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
        if (mutate.busy && !mutate.authWait)
            return;
        if (mutate.authWait)
            mutate.cancel();
        root.open = false;
        mutate.cancel();
        mutate.dismissError();
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
        root.query = String(text || "").slice(0, 80);
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

    function requestInstall(name: string) { mutate.requestInstall(name); }
    function requestRemove(name: string) { mutate.requestRemove(name); }
    function cancel() { mutate.cancel(); }
    function confirm() { mutate.confirm(); }
    function dismissError() { mutate.dismissError(); }

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
            root._loadNames(catalog.discoverNames(), "featured");
            return;
        }
        root._loadNames(catalog.packages(root.categoryId), "info");
    }

    function iconFor(id: string): string {
        return catalog.iconFor(id);
    }

    function iconForPkg(name: string): string {
        return catalog.iconForPkg(name);
    }

    function _valid(name: string): bool {
        return mutate.validName(name);
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
                root.sections = [];
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
        try {
            proc.running = false;
            root._mode = mode;
            root.loading = true;
            proc.command = cmd;
            proc.running = true;
        } catch (e) {
            root.loading = false;
            Logger.error("Store", String(e));
        }
    }

    function _rows(text: string) {
        try {
            const parsed = JSON.parse(String(text || "").trim() || "[]");
            return Array.isArray(parsed) ? parsed : [];
        } catch (e) {
            Logger.warn("Store", "package list parse failed");
            return [];
        }
    }

    function _procDone(code: int, out: string, err: string) {
        try {
            if (root._mode === "explicit") {
                if (code !== 0) {
                    root.results = [];
                    root.loading = false;
                    Logger.warn("Store", "explicit list failed");
                    return;
                }
                root._loadNames(root._rows(out), "info");
                return;
            }
            const rows = root._rows(out);
            if (root._mode === "featured")
                root.sections = catalog.groupRows(rows);
            else
                root.results = rows;
            root.loading = false;
            if (code !== 0 && rows.length === 0) {
                const t = String(err || "").trim();
                if (t.length)
                    Logger.warn("Store", t);
            }
        } catch (e) {
            root.loading = false;
            Logger.error("Store", String(e));
        }
    }

    IpcHandler {
        target: "store"
        function toggle() { root.toggle(); }
        function show() { root.show(); }
        function hide() { root.hide(); }
    }
}
