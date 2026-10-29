// pacman list/search for the Store singleton.
import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Item {
    id: root
    visible: false
    width: 0
    height: 0

    property var host: null
    property var catalog: null
    property var classify: null
    property var browse: null
    property var mutate: null
    property string _mode: ""

    Process {
        id: proc
        running: false
        stdout: StdioCollector { id: procOut }
        stderr: StdioCollector { id: procErr }
        onExited: (code) => root._procDone(code, procOut.text, procErr.text)
    }

    function reload() {
        const h = root.host;
        if (!h || !root.browse)
            return;
        root.browse.reset("");
        if (h.query.trim().length > 0) {
            root.runSearch();
            return;
        }
        if (h.categoryId === "installed") {
            root._start([Paths.script("pkg-explicit.sh")], "explicit");
            return;
        }
        if (h.categoryId === "discover") {
            root.loadNames(root.catalog.discoverNames(), "featured");
            return;
        }
        root.loadNames(root.catalog.packages(h.categoryId), "info");
    }

    function runSearch() {
        const h = root.host;
        const q = h.query.trim();
        if (!q.length) {
            root.reload();
            return;
        }
        const curated = root.catalog.search(q).filter((n) => root.mutate.validName(n));
        root._start([Paths.script("pkg-search.sh"), q].concat(curated), "search");
    }

    function loadNames(names, mode: string) {
        const argv = [Paths.script("pkg-info.sh")];
        const list = names || [];
        for (let i = 0; i < list.length; i++) {
            if (root.mutate.validName(list[i]))
                argv.push(list[i]);
        }
        if (argv.length < 2) {
            if (mode === "featured")
                root.host.sections = [];
            else {
                root.host.results = [];
                root.host.systemPkgs = [];
            }
            root.host.loading = false;
            root._readyMore(mode);
            return;
        }
        root._start(argv, mode);
    }

    function seen() {
        const out = [];
        const list = root.host.results || [];
        for (let i = 0; i < list.length; i++) {
            const n = String(list[i] && list[i].name || "");
            if (n.length)
                out.push(n);
        }
        return out;
    }

    function _start(cmd, mode: string) {
        try {
            proc.running = false;
            root._mode = mode;
            root.host.loading = true;
            proc.command = cmd;
            proc.running = true;
        } catch (e) {
            root.host.loading = false;
            Logger.error("Store", String(e));
        }
    }

    function _rows(text: string) {
        try {
            const parsed = JSON.parse(String(text || "").trim() || "[]");
            return Array.isArray(parsed) ? parsed : [];
        } catch (e) {
            return [];
        }
    }

    function _applyRows(rows) {
        const h = root.host;
        if (h.categoryId === "installed" && h.query.trim().length === 0) {
            const split = root.classify.splitInstalled(rows);
            h.results = split.apps;
            h.systemPkgs = split.system;
            return;
        }
        h.results = rows;
        h.systemPkgs = [];
    }

    function _readyMore(mode: string) {
        const h = root.host;
        if (mode === "search")
            root.browse.reset(h.query.trim());
        else if (mode === "info" && h.query.trim().length === 0)
            root.browse.reset(root.catalog.browseQuery(h.categoryId));
        else
            root.browse.reset("");
    }

    function _procDone(code: int, out: string, err: string) {
        const h = root.host;
        try {
            if (root._mode === "explicit") {
                if (code !== 0) {
                    h.results = [];
                    h.systemPkgs = [];
                    h.loading = false;
                    return;
                }
                root.loadNames(root._rows(out), "info");
                return;
            }
            const rows = root._rows(out);
            if (root._mode === "featured")
                h.sections = root.catalog.groupRows(rows);
            else
                root._applyRows(rows);
            h.loading = false;
            root._readyMore(root._mode);
            if (code !== 0 && rows.length === 0 && String(err || "").trim().length)
                Logger.warn("Store", String(err).trim());
        } catch (e) {
            h.loading = false;
            Logger.error("Store", String(e));
        }
    }
}
