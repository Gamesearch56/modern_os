pragma Singleton
// Zip the current selection into this folder, or extract a zip beside itself.
import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property var _sources: []
    property string _out: ""

    function ask() {
        const rows = Files.selected || [];
        const list = [];
        for (let i = 0; i < rows.length; i++) {
            const path = String(rows[i] || "");
            if (path.charAt(0) === "/")
                list.push(path);
        }
        if (!list.length || Files.place !== "folder" || Files.path.charAt(0) !== "/")
            return;
        root._sources = list;
        Files.namingKind = "zip";
        Files.naming = true;
    }

    function pack(name: string) {
        let leaf = String(name || "").trim();
        if (!leaf.toLowerCase().endsWith(".zip"))
            leaf += ".zip";
        const parent = String(Files.path || "");
        const dest = parent === "/" ? "/" + leaf : parent + "/" + leaf;
        Files.naming = false;
        root._run(["pack", dest].concat(root._sources));
    }

    function isZip(entry: var): bool {
        if (!entry || entry.dir)
            return false;
        return String(entry.name || entry.path || "").toLowerCase().endsWith(".zip");
    }

    function openZip(entry: var): bool {
        if (!entry || entry.dir || Files.place === "trash" || Files.place === "network")
            return false;
        if (!root.isZip(entry))
            return false;
        const path = String(entry.path || "");
        if (path.charAt(0) !== "/")
            return false;
        root.unpack(path);
        return true;
    }

    function unpack(path: string) {
        const file = String(path || "");
        const slash = file.lastIndexOf("/");
        const base = slash >= 0 ? file.slice(slash + 1) : file;
        const stem = base.toLowerCase().endsWith(".zip") ? base.slice(0, base.length - 4) : base;
        const parent = slash > 0 ? file.slice(0, slash) : "/";
        const leaf = stem.length ? stem : "archive";
        const dest = parent === "/" ? "/" + leaf : parent + "/" + leaf;
        root._run(["unpack", file, dest]);
    }

    function _run(args: var) {
        if (proc.running)
            return;
        root._out = "";
        proc.command = [Paths.script("files-zip.sh")].concat(args);
        proc.running = true;
    }

    Process {
        id: proc
        running: false
        stdout: StdioCollector { id: outBuf }
        stderr: StdioCollector { id: errBuf }
        onExited: (code) => {
            if (code !== 0) {
                Files.failed(String(errBuf.text || "").trim() || "refused");
                return;
            }
            let info = ({});
            try { info = JSON.parse(String(outBuf.text || "{}")); } catch (e) { info = ({}); }
            const made = String(info.path || "");
            if (made.charAt(0) === "/") {
                FilesUndo.note(["touch", made], JSON.stringify({ path: made }));
                Files.selected = [made];
            }
            Files.refresh();
        }
    }
}
